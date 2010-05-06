Support tools
*********************

.. sectionauthor:: Enrique J. Hernández <ejhernandez@ebox-platform.com>

When getting support  [#]_ for your eBox installation there are some tools which could
be used to ease the process

.

.. [#] http://www.ebox-technologies.com/services/support/



Configuration report
--------------------------------------

The configuration report is an archive which contains your eBox configuration
and a good deal of information about your system. Providing it could cut time
because in a lot of cases the information required by the support engineer would be
right there.


There are two ways to generate the report::
 * In the web interface go to 'System -> Configuration report'; click in the
   button for generate the report; when the report is ready it will be
   downloaded by your browser.
 * In the command line execute the command
   `/usr/share/ebox/configuration-report`. When the report is generated the
   command will show you its location in the file system.



Remote access support
-------------------------

In difficult cases, if your work environment allows it, it could be helpful to let
the support engineer access directly to your eBox server. 

The `ebox-remoteservices` package provides a feature to streamline this
procedure. The remote access is done using ssh and public key encryption; this
way is not need to share any password. The access will only be available as long
you have this feature enabled so is recommended to turn on only for the time
that is necessary.

Before enabling it you must meet those prerequisites:
 * Your server must be visible in Internet and you need to know which is his
   Internet address. You must supply this address to the support engineer.
 * sshd server must be running.
 * You firewall must be configured to allow the ssh connections.
 * In the sshd configuration file `PubkeyAuthentication` must _not_ be
   disabled. 


To enable it, go to :menuselection:`General->Remote access support` and check the
:guilabel:`Allow remote access to eBox staff` control, then save changes as
usual.

After giving the server's Internet address to the support engineer, he could be
able to login in your server as long the option is enabled.

You could use the `screen` program to see in real time the support's session,
this could be useful to share more information.

To be able to do this you must be logged with a user from the group `adm`, the
default user created during the installation process fits the bill. Once logged
you can join the session with this command::

screen -x ebox-remote-support/`

