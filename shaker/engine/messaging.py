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
import zmq

from oslo_config import cfg
from oslo_log import log as logging

from shaker.agent import agent
from shaker.engine import utils


LOG = logging.getLogger(__name__)

HEARTBEAT_AGENT = '__heartbeat'


class MessageQueue(object):
    def __init__(self, endpoint):
        ip, port = utils.split_address(endpoint)

        context = zmq.Context()
        self.socket = context.socket(zmq.REP)
        self.socket.bind("tcp://*:%s" % port)
        LOG.info('Listening on *:%s', port)

        heartbeat = multiprocessing.Process(
            target=agent.work,
            kwargs=dict(agent_id=HEARTBEAT_AGENT, endpoint=endpoint,
                        ignore_sigint=True))
        heartbeat.daemon = True
        heartbeat.start()

    def __iter__(self):
        try:
            while True:
                # Set a timeout(ms) based on agent_loss_timeout.
                # Add some padding so agent_loss_timeout
                # has a chance to fire correctly before the socket closes
                client_timeout = (cfg.CONF.agent_loss_timeout * 1000) + 3000
                # This prevents a hung process/thread when
                # server_endpoint is not reachable
                self.socket.setsockopt(zmq.RCVTIMEO, client_timeout)
                # If this is not set to 0 the socket will not
                # close even if timeout is reached
                self.socket.setsockopt(zmq.LINGER, 0)
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
