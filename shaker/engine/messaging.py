# Copyright (c) 2015 Mirantis Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import multiprocessing
import socket
import time
import zmq

from oslo_log import log as logging
from shaker.agent import agent
from shaker.engine import utils
from six.moves import zip_longest
from timeit import default_timer as timer

LOG = logging.getLogger(__name__)

HEARTBEAT_AGENT = '__heartbeat'


class MessageQueue(object):
    def __init__(self, endpoint):
        ip, port = utils.split_address(endpoint)

        context = zmq.Context()
        self.socket = context.socket(zmq.REP)
        self.socket.bind("tcp://*:%s" % port)
        LOG.info('Listening on *:%s', port)

        # Test that endpoint is actually reachable
        # otherwise the process will get stuck indefinately waiting
        # for a REQ/REP that will never happen.
        # The code to support this was adapted from pypi package tcping
        try:
            LOG.info("Testing route to %s" % endpoint)
            ping_test = Ping(ip, port)
            ping_test.ping(3)
            if ping_test._success == 0:
                raise socket.timeout("No valid route to %s" % endpoint)
        except socket.error as e:
            LOG.exception(e)
            raise

        heartbeat = multiprocessing.Process(
            target=agent.work,
            kwargs=dict(agent_id=HEARTBEAT_AGENT, endpoint=endpoint,
                        ignore_sigint=True))
        heartbeat.daemon = True
        heartbeat.start()

    def __iter__(self):
        try:
            while True:
                #  Wait for next request from client
                message = self.socket.recv_json()
                LOG.debug('Received request: %s', message)

                def reply_handler(reply_message):
                    self.socket.send_json(reply_message)
                    LOG.debug('Sent reply: %s', reply_message)

                try:
                    yield message, reply_handler
                except GeneratorExit:
                    break

        except BaseException as e:
            if isinstance(e, KeyboardInterrupt):  # SIGINT is ok
                LOG.info('Process is interrupted')
            else:
                LOG.exception(e)
                raise


class Socket(object):
    def __init__(self, family, type_, timeout):
        s = socket.socket(family, type_)
        s.settimeout(timeout)
        self._s = s

    def connect(self, host, port=80):
        self._s.connect((host, int(port)))

    def shutdown(self):
        self._s.shutdown(socket.SHUT_RD)

    def close(self):
        self._s.close()


class Timer(object):
    def __init__(self):
        self._start = 0
        self._stop = 0

    def start(self):
        self._start = timer()

    def stop(self):
        self._stop = timer()

    def cost(self, funcs, args):
        self.start()
        for func, arg in zip_longest(funcs, args):
            if arg:
                func(*arg)
            else:
                func()

        self.stop()
        return self._stop - self._start


class Ping(object):
    def __init__(self, host, port=80, timeout=1):
        self.timer = Timer()

        self._success = 0
        self._failed = 0
        self._conn_times = []
        self._host = host
        self._port = port
        self._timeout = timeout

    def _create_socket(self, family, type_):
        return Socket(family, type_, self._timeout)

    def ping(self, count=10):
        for n in range(1, count + 1):
            s = self._create_socket(socket.AF_INET, socket.SOCK_STREAM)
            try:
                time.sleep(1)
                cost_time = self.timer.cost(
                    (s.connect, s.shutdown),
                    ((self._host, self._port), None))
                s_runtime = 1000 * (cost_time)

                LOG.debug("Connected to %s[:%s]: seq=%d time=%.2f ms" % (
                    self._host, self._port, n, s_runtime))

                self._conn_times.append(s_runtime)
            except socket.timeout:
                LOG.error("Connected to %s[:%s]: seq=%d time out!" % (
                    self._host, self._port, n))
                self._failed += 1

            except KeyboardInterrupt:
                raise KeyboardInterrupt()

            else:
                self._success += 1

            finally:
                s.close()
