.. _webmail-ref:

WebMail service
***************

The **webmail** service allows users to read and send mail using a web
interface provided by the mail server itself.

Its main advantages are the no client configuration required by the user and
easily accessible from any web browser that could reach the server. Their downsides
are that the user experience is poorer than with most dedicated email user
software and that web access should be allowed by the server. It also increases
the server work load to render the mail messages, this job is done by
the client in traditional email software.

eBox uses **Roundcube** to implement this service [#]_.

.. [#] Roundcube webmail http://roundcube.net/

Configuring a webmail in eBox
-----------------------------

The **webmail** service is enabled like another eBox service. However,
it requires the **mail** module is configured to use either IMAP,
IMAPS or both and the **webserver** module enabled. If it is not,
webmail will refuse to enable itself. [#]_ 

.. [#] The mail configuration in eBox is deeply explained in
       :ref:`mail-service-ref` section and the webserver module is
       explained in :ref:`web-section-ref` section.

Webmail options
~~~~~~~~~~~~~~~

You can access to the options clicking in the :menuselection:`Webmail` section in
the left menu. You may establish the title that will use the
webmail to identify itself, this title will be shown in the login screen
and in the page HTML titles.

.. FIXME: Screenshot for webmail configuration

Login into the webmail
~~~~~~~~~~~~~~~~~~~~~~

In order to log into the webmail, firstly HTTP traffic must be allowed by the
firewall from the source address used. The webmail login screen is
available at `http://[eBox's address]/webmail` from the browser. 
Then it has to enter his email address and his password. He has to use his real
email address, an alias does not work.

.. FIXME: Shot with the webmail roundcube login screen

SIEVE filters
~~~~~~~~~~~~~

The **webmail** software also includes an interface to manage SIEVE
filters. It will only be available if the *ManageSIEVE* protocol is
enabled in the mail service. [#]_

.. [#] Check out :ref:`sieve-sec-ref` section for more information
