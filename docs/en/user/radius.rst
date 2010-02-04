.. _radius-ref:

RADIUS
******

.. sectionauthor:: Jorge Salamero Sanz <jsalamero@ebox-platform.com>

*Remote Authentication Dial In User Service* (*RADIUS*) is a networking protocol
that provides centralized *Authentication*, *Authorization* and *Accounting*
(*AAA*) management for computers to connect and use a network service.

The Authentication and Authorization flow in RADIUS work as the following:
the user or machine sends a request to a *Network Access Server* (*NAS*), like
could be a wireless Access Point, using the proper link-layer protocol in order to
gain access to a particular network resource using access credentials.
In turn, the NAS sends an *Access Request* message to the RADIUS server,
requesting authorization to grant access and including all the needed access
credentials, not only username and password but probably also realm, IP
address, VLAN to be assigned or maximum time to be connected.
This information is checked using authentication schemes like *PAP*, *CHAP*
or *EAP* and then a response is sent to the NAS:

#. *Access Reject*: when the user is denied access.
#. *Access Challenge*: when additional information is requested, like in TTLS
   where a tunneled dialog is established between the RADIUS server and the
   client for a second authentication phase.
#. *Access Accept*: when the user is granted access.

RADIUS official assigned IANA ports are 1812/UDP for Authentication and
1813/UDP for Accounting. This protocol does not transmit passwords in
cleartext between the NAS and the server (not even with PAP protocol), a
shared secret is used to encrypt the communication between both parties.

**FreeRADIUS** [#]_ server is being used for eBox RADIUS service.

.. [#] **FreeRADIUS** - *The world's most popular RADIUS Server* <http://freeradius.org/>.

RADIUS server configuration with eBox
=====================================

To configure the RADIUS server in eBox, first check in :guilabel:`Module Status`
if the :guilabel:`Users and Groups` module is enabled, as RADIUS depends on it.
Then, mark the :guilabel:`RADIUS` checkbox to enable the RADIUS eBox module.

.. figure:: images/radius/ebox-radius-01.png
   :scale: 80

   RADIUS General Configuration

To configure the service, go to :menuselection:`RADIUS` in the left menu. There
you will be able to setup the whether :guilabel:`All users` or only the users
who belong to one of your groups will be granted access.

All the NAS requesting authentication to eBox need to be defined on the
:guilabel:`RADIUS clients` section. For each NAS client we can specify:

:guilabel:`Enabled`: whether this NAS is enabled or not.

:guilabel:`Client`: the name for this client, like could be the hostname.

:guilabel:`IP Address`: the IP address or IP range allowed to send authentication
    requests to the RADIUS server.

:guilabel:`Shared Secret`: a shared password between the RADIUS server and the NAS
    to authenticate and encrypt their communication.

Access Point (AP) configuration
===============================

On every NAS you will need to setup the address of eBox as the RADIUS server, the
port, which defaults to 1812 and the shared secret. WPA and WPA2, using TKIP or AES
(recommended) can both be used with eBox RADIUS. The mode should be EAP.

.. figure:: images/radius/wireless-settings.png
   :scale: 80

   Access Point Wireless Settings

.. FIXME client configuration
