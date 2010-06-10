Support tools
*************

.. sectionauthor:: Javier Amor García <javier.amor.garcia@ebox-platform.com>
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>
                   

When getting support [#]_ for your eBox installation there are some
tools which could be used to ease the process.

.. [#] http://www.ebox-technologies.com/services/support/

Configuration report
--------------------

The **configuration report** is an archive which contains your eBox
configuration and a good deal of information about your system. By
providing it, it could cut time because in a lot of cases the
information required by the support engineer would be right there.

There are two ways to generate the report:


 1) In the web interface go to :menuselection:`System --> Configuration
    Report`; click in the button for generate the report; when the
    report is ready it will be downloaded by your browser.

 2) Through the command line run the command
    `/usr/share/ebox/configuration-report`. When the report is
    generated the command will show you its location in the file
    system.


Remote access support
---------------------

In some difficult cases, if your work environment permits it, it could
be helpful to let the support engineer access directly to your eBox
server.


The **ebox-remoteservices** package provides a feature to streamline this
procedure. The remote access is done using ssh and public key encryption  [#]_; this
way is not need to share any password. 

Moreover by default only is accessible through the virtual private network of the eBox
Control Center; this restriction is intended as additional security measure. For
the situations were the eBox is not subscribed to the Control Center or the
virtual private network isn't working properly exists a option to allow access
from any Internet address.

The access will only be available as long
you have this feature enabled so is recommended to turn on only for the time
that is necessary.

Before enabling it you must meet those prerequisites:
 
 * You server must be visible either from the Control Center's VPN or the Internet.
 * sshd server must be running.
 * You firewall must be configured to allow the ssh connections.
 * In the sshd configuration file `PubkeyAuthentication` must _not_ be
   disabled. 

To enable it, go to :menuselection:`General --> Remote access support`
and check the :guilabel:`Allow remote access to eBox staff` control,
then save changes as usual.

After giving the server's Internet IP address to the support engineer,
he could be able to log in in your server as long the option is
enabled.


If you want to allow access from the Internet, check also the option
:guilabel:`Allow access from any Internet address`. In this case you should give your
Internet address to the support engineer and make sure that ssh access is allowed
from the Internet.


Once is all set up the support engineer will be
able to login in your server as long this feature is enabled.

You could use the `screen` program to see in real time the support's session,
this could be useful to share more information.

To be able to do this you must be logged with a user from the group
**adm**, the default user created during the installation process fits
the bill. Once logged in, you can join the session with this command::


   screen -x ebox-remote-support/



Ask to the support engineer for letting you write in the same screen
session.

.. [#] There are more information about Public Key in :ref:`vpn-ref`
       chapter.