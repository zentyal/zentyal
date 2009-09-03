.. _firewall-ref:

Firewall
********

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>
                   Isaac Clerencia <iclerencia@ebox-platform.com>
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>
                   Víctor Jiménez <vjimenez@warp.es>
                   Javier Uruen <juruen@ebox-platform.com>

We will configure a firewall to see the application of the network objects and
services. A **firewall** is a system that strengthens the access control
policies between networks. In our case, a host will be devoted to
protecting our internal network and eBox from attacks from the external network.

A firewall allows the user to define a series of access policies, such as
which hosts can be connected to or which can receive data and the type thereof.
In order to do this, it uses rules that can filter traffic depending on
different parameters, such as the protocol, source or destination addresses
or ports used.

Technically speaking, the best solution is to have a computer with two or more
network cards that isolate the different connected networks (or segments thereof)
so that the firewall software is responsible for connecting the network
packages and determining which can be passed or not and to which network
they will be sent. By configuring the host as a firewall and router, traffic
packages can be exchanged between networks in a more secure manner.

The firewall in GNU/Linux: Netfilter
====================================

Starting with the Linux 2.4 kernel, a filtering subsystem known as
**Netfilter** is provided to offer packet filtering
and Network Address Translation (NAT) [#]_. The **iptables**
command interface allows for the different configuration tasks
to be performed for the rules affecting the filtering system (*filter*
table), rules affecting packet translation with NAT
(*nat* table) or rules to specify certain packet control and
handling options (*mangle* table). It is extremely flexible and
orthogonal to handle, although it adds a great deal of complexity and has a
steep learning curve.

.. [#] **NAT** *(Network Address Translation)*: this is the process of rewriting
         the source or destination of an IP packet as it passes through a router
         or firewall. Its main use is to provide several hosts in a private
         network with Internet access through a single public IP.

eBox security model
===================

The eBox security model is based on seeking to provide the utmost
default security, in turn trying to minimize the work of the administrator
regarding configuration when new services are added.

When eBox acts as a firewall, it is normally installed between the local
network and the *router* that connects that network to another, normally
Internet. The network interfaces connecting the host to the external
network (the *router*) must be marked as such. This enables the
**Firewall** module to establish default filtering policies.

.. figure:: images/firewall/filter-combo.png
   :alt: Graphic: Internal network - Filtering rules - External network
   :scale: 70

   Internal network - Filtering rules - External network

The policy for external interfaces is to deny all attempts of
new connections to eBox. Internal interfaces are denied all
connection attempts, except those made to internal services
defined in the **Services** module, which are accepted by
default.

Furthermore, eBox configures the firewall automatically to provide
**NAT** for packages entering through an internal interface and exiting through an
external interface. Where this function is not required, it may be disabled using
the **nat_enabled** variable in the firewall module configuration
file in **/etc/ebox/80firewall.conf**.

Firewall configuration with eBox
================================

For easier handling of **iptables** in filtering tasks, the eBox
interface in :menuselection:`Firewall --> Package
filtering` is used.

Where eBox acts as a gateway, filtering rules can be established
to determine whether the traffic from a local or remote
service must be accepted or not. There are five types of network
traffic that can be controlled with the filtering rules:

 * Traffic from an internal network to eBox
   (e.g. allow SSH access from certain hosts).
 * Traffic among internal networks and from internal networks to
   the Internet (e.g. forbid Internet access from a certain
   internal network).
 * Traffic from eBox to external networks (e.g. allow
   files to be downloaded by FTP from the host using eBox).
 * Traffic from external networks to eBox (e.g. enable the
   Jabber server to be used from the Internet).
 * Traffic from external networks to internal networks (e.g.
   allow access to an internal *Web* server from the Internet).

Bear in mind that the last two types of rules may jeopardize
eBox and network security and, therefore, must be used
with the utmost care. The filtering types can be seen in the
following graphic:

.. figure:: images/firewall/firewall-schema.png
   :alt: types of filtering rules
   :scale: 80

   *GRAPHIC: types of filtering rules*

eBox provides a simple way to control access to its services and to external
services from an internal interface (where the *intranet* is located) and the
Internet. It is normally object-configured. Hence, it is possible
to determine how a network object can access each of the eBox
services. For example, access could be denied to the DNS service by a certain
subnet. Furthermore, the Internet access rules are managed by eBox too, e.g. to
configure Internet access, outgoing packages to TCP ports 80 and 443 to any
address have to be allowed.

.. figure:: images/firewall/02-firewall.png
   :alt: list of package filtering rules from internal
         networks to eBox

   List of package filtering rules from internal networks to eBox

Each rule has a :guilabel:`source` and :guilabel:`destination` that
depend on the type of filtering used. For example, the
filtering rules for eBox output only require the establishing of the
destination, as the source is always eBox. A
specific :guilabel:`service` or its :guilabel:`reverse` can be used to
deny all output traffic, for example, except SSH
traffic. In addition, it can be given a :guilabel:`description` for
easier rule management. Finally, each rule has a
:guilabel:`decision` that can have the following values:

* Accept the connection.
* Deny connection by ignoring the incoming packages and making
  the source suppose that connection could not be established.
* Deny connection and also record it. Thus, through
  :menuselection:`Logs -> Log query` of the
  :guilabel:`Firewall`, it is possible to see whether a rule is working
  properly.

Port redirection
----------------

Port redirections (destination NAT) are configured through
:menuselection:`Firewall --> Redirection`, where an external port
can be given and all traffic routed to a host listening on a certain port
can be redirected by translating the destination address.

To configure a redirection, the following fields need to be specified:
:guilabel:`interface` where the translation is to be made, the
:guilabel:`original target` (this could be eBox, an IP address or an
object), the :guilabel:`original destination port` (this could be *any*,
a range of ports or a single port), the :guilabel:`protocol`, the
:guilabel:`source` from where the connection is to be started (in a
normal configuration, its value will be *any*), the
:guilabel:`target IP address` and, finally, the :guilabel:`destination
port`, where the target host is to receive the requests, which may or
may not be the same as the original.

.. image:: images/firewall/07-redirection.png
   :scale: 70
   :align: center
   :alt: editing a redirection

According to the example, all connections to eBox through the
*eth0* interface to port 8080/TCP will be redirected to port 80/TCP of
the host with IP address *10.10.10.10*.

Practical example
-----------------
Use the **netcat** program to create a simple server that listens
on port 6970 in the eBox host. Add a service and a firewall
rule so that an internal host can access the service.

To do so:

#. **Action:**
   Access eBox, enter :menuselection:`Module status` and enable the
   **Firewall** module by marking the checkbox in the
   :guilabel:`Status` column.

   Effect:
     eBox requests permission to take certain actions.

#. **Action:**
   Read the actions to be taken and grant permission to eBox
   to do so.

   Effect:
     The :guilabel:`Save changes` button has been enabled.

#. **Action:**
   Create an internal service as in :ref:`serv-exer-ref` of
   section :ref:`abs-ref` through :menuselection:`Services` with
   the name **netcat** and with the :guilabel:`destination
   port` 6970. Then go to :menuselection:`Firewall -->
   Package filtering` in :guilabel:`Filtering rules from internal
   networks to eBox` and add the rule with at least the
   following fields:

   - :guilabel:`Decision` : *ACCEPT*
   - :guilabel:`Source` : *Any*
   - :guilabel:`Service` : *netcat*. Created in this action.

   Once this is done, :guilabel:`Save changes` to confirm the
   configuration.

   Effect:
     The new **netcat** service has been created with a rule for
     internal networks to connect to it.

#. **Action:**
   From the eBox console, launch the following command::

     nc -l -p 6970

#. **Action:**
   From the client host, check that there is access to this
   service using the command **nc**::

     nc <ip_eBox> 6970

   Effect:
     You can send data that will be displayed in the terminal where you
     launched **netcat** in eBox.

.. include:: firewall-exercises.rst
