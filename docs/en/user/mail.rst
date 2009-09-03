.. _mail-service-ref:

Electronic Mail Service (SMTP/POP3-IMAP4)
*****************************************

.. sectionauthor:: Jose A. Calvo <jacalvo@ebox-platform.com>
                   Enrique J. Hernandez <ejhernandez@ebox-platform.com>
                   Víctor Jímenez <vjimenez@warp.es>

The **electronic mail** service is a store and forward method [#]_
to compose, send, store and receive messages over electronic
communication systems.

.. [#] **Store and forward**: Telecommunication technique in which 
       information is sent to an intermediate station where it is kept
       and sent at a later time to the final destination or to another
       intermediate station.

How electronic mail works through the Internet
==============================================

.. figure:: images/mail/mail-ab.png
   :scale: 60
   :alt: Diagram where Alice sends an email to Bob

   Diagram where Alice sends an email to Bob

The diagram depicts a typical event sequence that takes place when
Alice writes a message to Bob using her *Mail User Agent* (MUA).

1. Her MUA formats the message in email format and uses the
   *Simple Mail Transfer Protocol* (SMTP) to send the message to the
   local *Mail Transfer Agent* (MTA).
2. The MTA looks at the destination address provided in the SMTP (not
   from the message header), in this case bob@b.org, and resolves a
   domain name to determine the fully qualified domain name of the
   destination mail exchanger server (**MX** record that was explained
   in the DNS section).
3. **smtp.a.org** sends the message to **mx.b.org** using SMTP, which
   delivers it to the mailbox of the user **bob**.
4. Bob receives the message through his MUA, which picks up the
   message using *Pop Office Protocol* (POP3).

There are many alternative possibilities and complications to the
previous email system sequence. For instance, Bob may pick up his
email in many ways, for example using the *Internet Message Access
Protocol* (IMAP), by logging into mx.b.org and reading it directly, or
by using a **Webmail** service.

The sending and reception of emails between mail servers is done through SMTP
but the users pick up their email using POP3 or IMAP. Using these protocols
provides interoperability among different servers and email clients. There
are also proprietary protocols such as the ones used by *Microsoft Exchange* 
and *IBM Lotus Notes*.

POP3 vs IMAP
------------

The POP3 design to retrieve email messages is useful for slow connections,
allowing users to pick up all their email all at once to see and
manage it without being connected. These messages are usually removed
from the user mailbox in the server, although most MUAs allow to keep them
on the server.

The more modern IMAP, allows to work on-line or offline as well as
to explicitly manage server stored messages. Additionally, it allows
simultaneous access by multiple clients to the same mailbox or partial fetches
from MIME messages among other advantages. However, it is a quite complicated
protocol with more server work load than POP3, which puts most of the load on
the client side. The main advantages over POP3 are:

- Connected and disconnected modes of operation.
- Multiple clients simultaneously connected to the same mailbox.
- Access to MIME message parts and partial fetch.
- Message state information using *flags* (read, removed, replied, ...).
- Multiple mailboxes on the server (usually presented to the user as
  folders) allowing to make some of them public.
- Server-side searches
- Built-in extension mechanism

SMTP/POP3-IMAP4 server configuration with eBox
==============================================

Setting up an email system service requires to configure an MTA to send
and receive emails as well as IMAP and/or POP3 servers to allow users
to retrieve their mails.

To send and receive emails Postfix [#f1]_ acts as SMTP server. The email
retrieval service (POP3, IMAP4) is provided by Dovecot [#f2]_. Both
servers support secure communication using SSL.

.. rubric:: Footnotes

.. [#f1] **Postfix** The Postfix Home Page http://www.postfix.org .

.. [#f2] **Dovecot** Secure IMAP and POP3 Server http://www.dovecot.org .

General configuration
---------------------

Through :menuselection:`Mail --> General --> Mail server options` you
can access the general configuration to :guilabel:`require authentication`,
to send email messages through the server or allow the SMTP communication
encryption using the :guilabel:`TLS for SMTP server` setting.

.. image:: images/mail/01-general.png

In addition, the *relay* service is provided, that is, forwarding email
messages whose source and destination are different from any of the
domains managed by the server.

Furthermore, in :menuselection:`Mail --> General --> Mail server
options` you can configure eBox to not send messages directly but
by using a *smarthost*, which is in charge of sending them.
Each received email will be forwarded to the *smarthost* without
keeping a copy. In this case, eBox would be an intermediary between the
user who sends the email and the server which is the real message
sender. The following settings can be configured:

:guilabel:`Smarthost to send mail`:
  Domain name or IP address.
:guilabel:`Smarthost authentication`:
  Whether the smarthost requires authentication using
  user and password or not.
:guilabel:`Maximum message size accepted`:
  Indicates, if necessary, the maximum message size accepted by the
  smarthost in MB.

In order to configure the mail retrieval services go to
the :guilabel:`Mail retrieval services` section. There eBox may be
configured as POP3 and/or IMAP4 server, both allowing SSL support.

In addition to this, eBox may be configured to act as a *smarthost*. To
do so, you can add relay policies for network objects through
:menuselection:`Mail --> General --> Relay policy for network objects`.
The policies are based on the source mail server IP address. If the relay is
allowed from a object, then each object member may send emails through eBox.

.. image:: images/mail/02-relay.png

.. warning::
   Be careful when using an *Open Relay* policy, i.e., forwarding
   email from everywhere, since your mail server will probably
   become a *spam* source.

Finally, the mail server may be configured to use a content filter for
their messages [#]_. To do so, the filter server must receive the
message from a fixed port and send the result back to another fixed port
where the mail server is bound to listen the response. Through
:menuselection:`Mail --> General --> Mail filter options`, you may
choose a custom server or eBox as mail filter.

.. [#] In  :ref:`mailfilter-sec-ref` section this topic is explained in depth.

.. image:: images/mail/mailfilter-options.png
   :align: center

Email account creation through virtual domains
-----------------------------------------------

In order to set up an email account with a mailbox, a virtual domain and
a user are required. From :menuselection:`Mail --> Virtual Mail Domains`,
you may create as many virtual domains as you want. They provide the
*domain name* for email accounts for eBox users. Moreover, it is
possible to set *aliases* for a virtual domain. It does not make any difference
to send an email to one virtual domain or any of their aliases.

.. image:: images/mail/mail-vdomains.png
   :align: center

In order to set up email accounts, you have to follow the same rules than 
when configuring file sharing. From
:menuselection:`Users --> Edit User --> Create mail account`.
There, you select the main virtual domain for the user. If you want to
assign to the user more than a single email address, you can use aliases.
Behind the scenes, the email messages are kept just once in a mailbox.

.. TODO: Explain how to authenticate using alias since they are not
         real accounts

.. image:: images/mail/03-user.png
   :align: center
   :scale: 80

Likewise, you may set up *aliases* for user groups. Messages received
by these aliases are sent to every user of the group. Group aliases are
created through
:menuselection:`Groups --> Edit Group --> Create alias mail account to
group`.

.. FIXME: group mail alias account is required

Queue Management
----------------

From :menuselection:`Mail --> Queue Management`, you may see those
email messages that haven't already been delivered. All
the information about the messages is displayed. The allowed actions to perform
are:
deletion, content viewing or send retrying (*re-queuing* the
message again).

.. image:: images/mail/04-queue.png
   :align: center

.. _mail-conf-exercise-ref:

Practice example
^^^^^^^^^^^^^^^^

Set up a virtual domain for the mail service. Create a user account
and a mail account within the domain for that user. Configure the
*relay* policy to send email messages. Send a test email message
with the new account to an external mail account.

#. **Action:**
   Log into eBox, access :menuselection:`Module status` and enable
   **Mail** by checking its checkbox in the :guilabel:`Status` column.
   Enable **Network** and **Users and Groups** first if they
   are not already enabled.

   Effect:
     eBox requests permission to overwrite certain files.

#. **Action:**
   Read the changes of each of the files to be modified and
   grant eBox permission to overwrite them.

   Effect:
     The :guilabel:`Save changes` button has been enabled.

#. **Action:**
   Go to :menuselection:`Mail --> Virtual Mail Domains` and click
   :guilabel:`Add new` to create a new domain. Enter the name in
   the appropriate field.

   Effect:
     eBox notifies you that you must save changes to use this virtual
     domain.

#. **Action:**
   Save the changes.

   Effect:
     eBox displays the progress while the changes are being applied. Once this is
     completed, you will be notified.

     Now you may use the newly created virtual mail domain.

#. **Action:**
   Enter :menuselection:`Users --> Add User`,
   fill up the user data and click the :guilabel:`Create` button.

   Effect:
     The user is added immediately without saving changes. The edition
     screen is displayed for the newly created user.

#. **Action:**
   Introduce a name for the user mail account in
   :guilabel:`Create mail account` and create it.

   Effect:
     The account has been added immediately and options to delete it
     or add *aliases* for it are shown.

#. **Action:**
   Enter the :menuselection:`Object --> Add new` menu. Fill in a name for
   the object and press :guilabel:`Add`. Click on :guilabel:`Members`
   in the created object. Fill in again a name for the member and write
   the host IP address where the mail will be sent from.

   Effect:
     The object has been added temporarily and you may use it in other
     eBox sections, but it is not persistent until you save changes.

#. **Action:**
   Enter :menuselection:`Mail --> General --> Relay policy for network
   objects`. Select the previously created object making sure
   :guilabel:`Allow relay` is checked and add it.

   Effect:
     The :guilabel:`Save changes` button has been enabled.

#. **Action:**
   Save the changes

   Effect:
     A relay policy for that object has been added, which makes
     possible from that object to send e-mails to the outside.

#. **Action:**
   Configure a selected MUA in order to use eBox as SMTP server and
   send a test email message from this new account to an external
   one.

   Effect:
     After a brief period you should receive the message in your
     external account mailbox.

#. **Action:**
   Verify using the mail server log file `/var/log/mail.log`
   that the email message was delivered correctly.

.. include:: mail-exercises.rst
