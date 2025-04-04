Shaker
======

**The distributed data-plane testing tool built for OpenStack.**

Shaker wraps around popular system network testing tools like
`iperf <https://iperf.fr/>`_, `iperf3 <https://iperf.fr/>`_
and netperf (with help of `flent <https://flent.org/>`_).
Shaker is able to deploy OpenStack instances and networks in different
topologies. Shaker scenario specifies the deployment and list of tests
to execute. Additionally tests may be tuned dynamically in command-line.

Features
--------
* User-defined topology via Heat templates
* Simultaneously test execution on multiple instances
* Interactive report with stats and charts
* Built-in SLA verification

Deployment Requirements
-----------------------
* Shaker server routable from OpenStack cloud
* Admin-user access to OpenStack API is preferable
* Shaker image - created using disk-image-create

.. code-block:: bash

    $ tox -e venv -- disk-image-create -o shaker-image.qcow2 ubuntu
       vm -p dib-python install-types package-installs source-repositories
       pip-and-virtualenv

Build and install
-----------------

.. code-block:: bash

   $ python3 setup.cfg build
   $ sudo python3 setup.cfg install

Run in Python Environment - Default mode
----------------------------------------

.. code-block:: bash

   $ shaker --server-endpoint <host:port> --scenario <scenario> --report <report.html>

where:
    * ``host`` and ``port`` - host and port of machine where Shaker is deployed
    * ``scenario`` - the scenario to execute, e.g. `openstack/perf_l2` (
      `catalog <http://pyshaker.readthedocs.io/en/latest/catalog.html>`_)
    * ``<report.html>`` - file to store the final report

Full list of parameters is available in `documentation <http://pyshaker.readthedocs.io/en/latest/tools.html#shaker>`_.

Run in Python Environment - IPv6 extension
-------------------------

The support to use the subnet IPv6 address for tests was introduced with the
new agent engine parameter: --agent-ipv6

We could use the ipv6 subnet address without need this flag in an ipv6 only
scenario. However, the metadata is not supported in IPv6 only when the SDN
backend use the OVN driver. In this case, we need to use a dual stack mode
(multiple subnets), and it is not guaranteed that the ipv6 subnet will always
be in the same order [subnet index required by HEAT template].

HEAT output reference

.. code-block::

  outputs:
  {{ agent.id }}_ip:
    value: { get_attr: [ {{ agent.id }}, networks, { get_attr: [private_net, name] }, 0 ] }

IPv6 example:

.. code-block:: bash

   $ shaker --server-endpoint [IPv6_host]:port --scenario <dual_stack_scenario> --report <report.html>

where:
    * ``IPv6_host`` and ``port`` - host and port of machine where Shaker is deployed
    * ``--agent-ipv6`` - host and port of machine where Shaker is deployed
    * ``dual_stack_scenario`` - the custom scenario to execute a dual-stack deployment, e.g. `openstack/custom/l2_ipv6`
    * ``<report.html>`` - file to store the final report


Custom Scenarios
----------------

All custom scenarios use a Cross-AZ deployment.

Test Template base: Traffic executor and Runtime (.yaml)

.. code-block::

  execution:
    tests:
    -
      title: TCP
      class: iperf3
      time: 3600
      bandwidth: 100M
      sla:
      - "[type == 'agent'] >> (stats.bandwidth.avg > 45)"
    -
      title: UDP
      class: iperf3
      time: 3600
      udp: on
      bandwidth: 100M
      sla:
      - "[type == 'agent'] >> (stats.loss.avg < 25)"
    -
      title: Ping
      class: flent
      method: ping
      time: 10
      sla:
      - "[type == 'agent'] >> (stats.ping_icmp.avg < 300.0)"

OpenStack L2 Cross-AZ
^^^^^^^^^^^^^^^^^^^^^

* IPv4 only

  To use this scenario specify parameter ``--scenario openstack/custom/l2_ipv4``.

* Dual-Stack - IPv4 + IPv6

  To use this scenario specify parameter ``--scenario openstack/custom/l2_ipv4``.


OpenStack L3 East-West Cross-AZ
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* IPv4 only

  To use this scenario specify parameter ``--scenario openstack/custom/l3_east_west_ipv4``.

* Dual-Stack - IPv4 + IPv6

  To use this scenario specify parameter ``--scenario openstack/custom/l3_east_west_ipv6``.


OpenStack L3 North-South Cross-AZ
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* IPv4 only

  - Normal case: VM primary: private_ipv4 and VM minion: FIP address

    * To use this scenario specify parameter ``--scenario openstack/custom/l3_north_south_ipv4``.

  - FIP to FIP case: VM primary: FIP and VM minion: FIP address

    * To use this scenario specify parameter ``--scenario openstack/custom/l3_north_south_ipv4_fip_to_fip``.


* Dual-Stack - IPv4 + IPv6

  To use this scenario specify parameter ``--scenario openstack/custom/l3_north_south_ipv6``.


Custom Scripts - OpenStack project support
------------------------------------------

Shaker agent pairs use a set of deployed elements, e.g. network, subnets,
security group, FIP, etc.

To make test management easy and scale, each scenario created will be
associated with a new openstack project, and all resources will be linked
to that project. This removes the need to change default quotas on
openstack resources.

The test script creates a shaker scenario with a simple accommodation: 
a pair of agents with one agent on each compute node - Cross-AZ.

.. code-block::
  
  accommodation: [pair, single_room, cross_az, density: 1, compute_nodes: 2]

Shaker script

.. code-block:: bash

   $ ./run_shaker.sh SCENARIO HOST PORT NUMTEST SLEEP TESTPATH PROVIDER ZONE EXTRAFLAG &

where:
    * ``SCENARIO`` - the scenario to execute, e.g. `openstack/custom/l3_north_south_ipv6`
    * ``HOST`` - IPv6 address, e.g. [2001:db8::100]
    * ``PORT`` - start port, e.g. starts at 20000 and increments by one for each new scneario created
    * ``NUMTEST`` - The number of tests created for this scenario
    * ``SLEEP`` - The sleep time between each stack creation, e.g. 30 seconds
    * ``TESTPATH`` -  Path to store the final report, relative to /var/www/html/shaker/
    * ``PROVIDER`` - The external provider network.
    * ``ZONE`` - Comma-separated list of availability_zone, e.g. shaker-1a,shaker-1b
    * ``EXTRAFLAG`` - Extra shaker flags, e.g. --agent-ipv6

* The execution results are saved in the relative logs directory (./logs) and
named shaker_PORT.log, e.g. logs/shaker_20000.log

* The report results are saved in the http directory (/var/www/html/shaker/),
concatenated with the TESTPATH and named $PROJECT_NAME.dense_test.html 

IPv6 N/S example

.. code-block:: bash

   $ ./run_shaker.sh openstack/custom/l3_north_south_ipv6 [2001:db8::100] 20000 500 30 ipv6_test_1 provider1 shaker-1a,shaker-1b --agent-ipv6 &

Links
-----
* PyPi - https://pypi.org/project/pyshaker/
* Docs - https://pyshaker.readthedocs.io/
* Bugtracker - https://launchpad.net/shaker

