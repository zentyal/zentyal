.. webmail-ref:

WebMail service
***************

The webmail service allows the users to read and send mail using a web interface
provided by the mail server itself.

It has the advantages that the user has not to configure anything and it could
access to him mail from any browser that could reach the server. Their downsides
is that the user experience is poorer than with most dedicated email user
software and that web access should be allowed by the server. It also increases
the server's load more than traditional client-side email software.

eBox uses Roundcube to implement this service [#]_.

.. [#] Roundcube webmail http://roundcube.net/ .



Enabling the webmail service
----------------------------

The webmail service is enabled like another eBox service. However it requires
that the mail service is configured to use either IMAP, IMAPS or both. If it is
not, webmail will refuse to enable itself.


Webmail options
---------------

We can access to the options clicking in the :menuselection:`Webmail` section in
the left menu. In the options form we can establish the title that will use the
webmail to identify itself, this title will be shown in the login screen
and in the pages titles.


Login into the webmail
-------------------------

To log into the webmail, first we need that HTTP traffic is allowed by the
firewall from the source address used.

To get the webmail login screen the user has to point its browser to
`http://[server's address]/webmail`. 

Then it has to enter his email address and his password. He has to use his real
email address, an alias would not work.


SIEVE filters
--------------

The webmail also includes a interface to manage SIEVE filters. It will only be
available if the ManageSIEVE protocol is enabled in the mail service.