Routing
*******

.. sectionauthor:: Isaac Clerencia <iclerencia@ebox-platform.com>
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>
                   Víctor Jiménez <vjimenez@warp.es>

Routing tables
==============

The term **routing** refers to the action of deciding through which interface
a certain packet must be sent from a host.  The operating system has a routing
table with a set of rules to make this decision.

Each of these rules has different fields, although the three most
important ones are: :guilabel:`destination address`,
:guilabel:`interface` and :guilabel:`router`. These must be read as
follows: to reach a certain :guilabel:`destination address`,
the packet must be directed through a :guilabel:`router`,
which is accessible through a certain :guilabel:`interface`.

When the message arrives, its destination address is compared to the entries in
the table and is sent through the interface indicated in the rule that matches.
The best match is considered the most specific rule. For example, if a rule is
specified indicating that to reach network A (10.15.0.0/16), *router* A must be
used and another rule indicates that to reach network B (10.15.23.0/24), which
is a subnet of A, *router* B must be used. If a packet arrives with destination
10.15.23.23/32, then the operating system will decide to send it to *router B*,
as there is a more specific rule.

All hosts have at least one routing rule for the *loopback* interface, or local
interface, and additional rules for other interfaces that connect it to other
internal networks or to Internet.

To manually configure a static route table, :menuselection:`Network --> Routes`
is used (basically it is an interface for the **route** or **ip route**
commands). These routes may be overwritten if the DHCP protocol is used.

.. figure:: images/routing/11-routing.png
   :scale: 60
   :alt: route configuration
   :align: center

   Route configuration

Gateway
-------

When sending a packet, if no route matches and there is a gateway
configured, it will be sent through the gateway.

The *gateway* is the route by default for packets sent to other networks.

To configure a gateway, use :menuselection:`Network --> Routers`.

.. image:: images/routing/11-routing-gateways.png
   :scale: 80
   :alt: gateway configuration
   :align: center

Name:
  Name identifying the gateway.
IP address:
  IP address of the gateway. This address must be accessible from
  the host containing eBox.
Interface:
  Network interface connected to the gateway. Packages sent to the
  gateway will be sent through this interface.
Upload/Download:
  Upload and download rates supported by the gateway. These values are
  used by the traffic shaping module.
Weight:
  The heavier the weight, the more traffic will be directed to this gateway
  when load balancing is enabled.
Default:
  Indicates if this gateway should be used as the default one.

Subnets and subnet routing
--------------------------

As indicated above, initially there were classes of networks with associated
fixed network masks, which were 8-bit multiples. Due to the lack of scalability
of this approach, CIDR *(Classless Inter-Domain Routing)* was created to allow
for network masks of a variable size to be used, allowing, for example, for a
class C network to be divided into several subnets of a smaller size or to
aggregate several class C subnets into one of a larger size. This allows:

* A more effective use of the scarce IPv4 address space.
* Better use of the hierarchy in address assignment (adding of
  prefixes), decreasing routing overload throughout the
  Internet.

The number of bits interpreted as the subnet identifier is given by a *netmask*
that is of the same length as the IP address. To find the network of an IP
address with its mask, proceed as follows:

+-----------------+-------------------------+-------------------------------------+
|                 | Address with full stops | Binary                              |
+=================+=========================+=====================================+
| IP address      | 192.168.5.10            | 11000000.10101000.00000101.00001010 |
+-----------------+-------------------------+-------------------------------------+
| Netmask         | 255.255.255.0           | 11111111.11111111.11111111.00000000 |
+-----------------+-------------------------+-------------------------------------+
| Network portion | 192.168.5.0             | 11000000.10101000.00000101.00000000 |
+-----------------+-------------------------+-------------------------------------+

CIDR also introduced a new nomenclature that can be seen compared to
the above in the following table:

+------+---------+------------+-----------------+
| CIDR | Class   | N Hosts    | Mask            |
+======+=========+============+=================+
| /32  | 1/256 C | 1          | 255.255.255.255 |
+------+---------+------------+-----------------+
| /31  | 1/128 C | 2          | 255.255.255.254 |
+------+---------+------------+-----------------+
| /25  | 1/2 C   | 128        | 255.255.255.128 |
+------+---------+------------+-----------------+
| /24  | 1 C     | 256        | 255.255.255.0   |
+------+---------+------------+-----------------+
| /21  | 8 C     | 2048       | 255.255.248.0   |
+------+---------+------------+-----------------+

Practical example A
^^^^^^^^^^^^^^^^^^^

You will now configure the network interface statically. The class will be
divided into two subnets.

To do so:

#. **Action:**
   Access the eBox interface, enter :menuselection:`Network --> Interfaces` and,
   for the :guilabel:`network interface` *eth0*, select the :guilabel:*Static*
   `method`. As the :guilabel:`IP address`, enter that indicated by the
   instructor.  As the :guilabel:`Netmask`, use 255.255.255.0. Click on the
   :guilabel:`Change` button.

   The network address will be of the form 10.1.X.Y, where 10.1.X corresponds to
   the network and Y to the host. These values will be used from now on.

   Enter :menuselection:`Network --> DNS` and click on :guilabel:`Add`. As the
   :guilabel:`Name server` enter 10.1.X.1. Click on :guilabel:`Add`.

   Effect:
     The :guilabel:`Save changes` button has been enabled and the network
     interface keeps the data entered. A list is displayed containing the name
     servers, including the recently created server.

#. **Action:**
   Save the changes.

   Effect:
     eBox displays the progress while the changes are being applied.

#. **Action:**
   Access :menuselection:`Network --> Diagnosis`. Ping ebox-platform.com.

   Effect:
     The following is given as the result::

       connect: network is unreachable

#. **Action:**
   Access :menuselection:`Network --> Diagnosis`. Ping to an eBox of a classmate
   part of the same subnet.

   Effect:
     Three satisfactory connection attempts to the host are displayed as
     the result.

#. **Action:**
   Access :menuselection:`Network --> Diagnosis`. Ping to the
   eBox of a classmate in the other subnet.

   Effect:
     The following is given as the result::

       connect: network is unreachable

Practical example B
^^^^^^^^^^^^^^^^^^^

You will now configure a route to access hosts in other subnets.

To do so:

#. **Action:**
   Access the eBox interface, enter :menuselection:`Network --> Routes` and
   select :guilabel:`Add new`. Complete the form with the following values:

   :Network:     10.1.X.0 / 24
   :Gateway:     10.1.1.1
   :Description: route to the other subnet

   Click on the :guilabel:`Add` button.

   Effect:
     The :guilabel:`Save changes` button has been enabled. A list is displayed
     containing the routes, including the recently created one.

#. **Action:**
   Save the changes.

   Effect:
     eBox displays the progress while the changes are being applied.


#. **Action:**
   Access :menuselection:`Network --> Diagnosis`. Ping ebox-platform.com.

   Effect:
     The following is given as the result::

       connect: network is unreachable

#. **Action:**
   Access :menuselection:`Network --> Diagnosis`. Ping to the eBox of a
   classmate in the other subnet.

   Effect:
     Three satisfactory connection attempts to the host are displayed as
     the result.

Practical example C
^^^^^^^^^^^^^^^^^^^

You will now configure a gateway to connect to the remaining networks.

To do so:

#. **Action:**
   Access the eBox interface, enter :menuselection:`Network --> Routes` and
   delete the route created during the previous exercise.

   Enter :menuselection:`Network --> Routers` and select
   :guilabel:`Add new`. Complete with the following data:

   :Name:     Default Gateway
   :IP address: 10.1.X.1
   :Interface:  eth0
   :Upload:     0
   :Download:   0
   :Weight:     1
   :Default:    yes

   Click on the :guilabel:`Add` button.

   Effect:
     The :guilabel:`Save changes` button has been enabled. The list of routes
     has disappeared. A list of gateways is displayed containing the recently
     created gateway.

#. **Action:**
   Save the changes.

   Effect:
     eBox displays the progress while the changes are being applied.


#. **Action:**
   Access :menuselection:`Network --> Diagnosis`. Ping ebox-platform.com.

   Effect:
     Three satisfactory connection attempts to the host are displayed as
     the result.

#. **Action:**
   Access :menuselection:`Network --> Diagnosis`. Ping to the eBox of a
   classmate in the other subnet.

   Effect:
     Three satisfactory connection attempts to the host are displayed as
     the result.

Multirouter rules and load balancing
====================================

**Multirouter rules** are a tool that enables PCs in a network to use several
*Internet* connections transparently. This is useful if, for example, an office
has several ADSL connections and the entire bandwidth available is to be used
without having to worry about distributing the work of the hosts manually
between both *routers*, so that the load is shared automatically between them.

Basic **load balancing** evenly distributes the packets transferred from
eBox to the *Internet*. The simplest form of configuration involves establishing
different **weights** for each *router* so that, if the connections available
have different capacities, they can be used optimally.

*Multirouter* rules allow for certain traffic types to be sent permanently by
the same *router*, where required. Common examples include sending emails
through a certain *router* or ensuring that a certain subnet is always routed
from the Internet through the same *router*.

eBox uses the **iproute2** and **iptables** tools for the configuration required
for the *multirouter* function. **iproute2** informs the *kernel* of the
availability of several *routers*. For *multirouter* rules, **iptables** is used
to mark the packets of interest. These marks can be used from **iproute2** to
determine the *router* through which a packet must be sent.

There are several possible problems that must be considered. Firstly, the
connection concept does not exist in **iproute2**. Therefore, with no other
type of configuration, the packets belonging to the same connection could
end up being sent by different *routers*, making communications impossible.
To solve this, **iptables** is used to identify the different connections and
ensure that all the packets of a connection are sent via the same *router*.

The same applies to any incoming connections established. All response
packets for a connection must be sent using the same *router* through which
that connection was received.

To establish a *multirouter* configuration with load balancing in eBox, as many
*routers* as required must be defined in :menuselection:`Network --> Routers`.
Using the :guilabel:`weight` parameter when configuring a *router*, it is
possible to determine the proportion of packets that each one will send. Where
two *routers* are available and weights of 5 and 10, respectively, are
established, 5 of every 15 packets will be sent through the first router,
while the the remaining 10 will be sent via the second.

.. image:: images/routing/01-gateways.png
   :scale: 80
   :align: center

*Multirouter* rules and traffic balancing are established in the
:menuselection:`Network --> Traffic balancing` section. In this section,
it is possible to add rules to send certain packets to a specific
*router*, depending on the input :guilabel:`interface`, the
:guilabel:`source` (this could be an IP address, an object, eBox or
any), the :guilabel:`destination` (an IP address or a network
object), the :guilabel:`service` with which this rule is to be associated and
via which :guilabel:`routers` the traffic type specified is to be
directed.

.. image:: images/routing/02-gateway-rules.png
   :scale: 80
   :align: center

Practical example D
-------------------

Configure a *multirouter* scenario with several *routers* with different weights
and check that it works using the **traceroute** tool.

To do so:

#. **Action:**
   In pairs, leave one eBox with the current configuration and add
   a new *gateway* in the other, accessing
   :menuselection:`Network --> Routers` via the interface and clicking on
   :guilabel:`Add new`, with the following data:

   :Name:         Gateway 2
   :IP address:   <classmate's eBox IP>
   :Interface:       eth0
   :Upload:         0
   :Download:         0
   :Weight:           1
   :Default: yes

   Click on the :guilabel:`Add` button.

   Effect:
     The :guilabel:`Save changes` button has been enabled. A list of gateways
     is displayed containing the recently created gateway and the previous
     gateway.

#. **Action:**
   Save the changes.

   Effect:
     eBox displays the progress while the changes are being applied.

#. **Action:**
   Go to a console and run the following *script*::

      for i in $(seq 1 254); do sudo traceroute -I -n 155.210.33.$i -m 6; done

   Effect:
     The result of running **traceroute** shows the
     different *routers* through which a packet passes to reach its
     destination. On running it in a host with *multirouter*
     configuration, the result of the first leaps between *routers*
     should be different depending on the *router* chosen.

.. include:: routing-exercises.rst
