===============
Getting started
===============

Intro
=====

This tutorial is meant to be an easy-to-follow guide for developing new Zentyal
modules and extending the features of the existing ones.

We will show you the necessary steps to implement a full-fledged Zentyal
module, using an incremental development approach.

The Zentyal framework has a clear goal: make life easier for those developers and
system integrators who want to create an UI to manage Linux services integrated with
other services using the same technology. We want developers to focus only on
adding functionality with the service their modules manage. The framework tries
hard to keep you away from messing with HTML, CGIs, the interaction between the
different modules and so on.

Requirements
============

You should be familiar with a programming language. Although modules are
written in Perl, the data structures and syntax should be easily understood by
newcomers.

We will start building and running the code, for that you will need a machine
running Ubuntu Lucid. We strongly recommend the use of virtual machines for
Zentyal development. You can use VirtualBox [#]_ with a clean Zentyal 2.1
(development version) installation to start up. The reason to work with an
already installed Zentyal environment is to avoid solving dependency problems
when installing packages with *dpkg*. It's always a good practice to use the
snapshot capabilities to keep a clean environment where to go back.

Learning to build from source
=============================

One of the first steps to get involved with the project development is to be able
to build the software from the source. You can download the Zentyal source code
from our Subversion repository [#]_. Let's see how to fetch Zentyal source and
build everything from scratch.

First install some basic development tools::

    sudo apt-get install --no-install-recommends \
    subversion autoconf automake gettext dpkg-dev devscripts cdbs liberror-perl

Then you have to fetch *trunk* which is the main development branch. You will also
have to download the *scripts* directory too::

    mkdir ~/zentyal ; cd ~/zentyal
    svn co http://svn.zentyal.org/zentyal/trunk/
    svn co http://svn.zentyal.org/zentyal/scripts/

Now add the *zentyal-package* script to your PATH::

    mkdir ~/bin ; cd ~/bin
    ln -s ~/zentyal/scripts/zentyal-package .

After spawning a new shell to add the new *bin* directory to your PATH, if you
go to the *trunk* directory, you will be able to start building the Zentyal
packages::

    cd ~/zentyal/trunk
    zentyal-package common
    zentyal-package core
    zentyal-package software
    zentyal-package network
    zentyal-package services
    zentyal-package objects
    zentyal-package firewall

... and so on. Now you only need to copy the packages to the virtual machine and
install them. If you don't have these modules already installed you will have
to deal with the missing depends::

    scp debs-ppa/*.deb user@zentyal-dev:
    ssh user@zentyal-dev
    sudo dpkg -i --force-all *.deb

You can find all Zentyal modules inside the *main* directory::

    $ ls -1 main/
    antivirus
    asterisk
    ca
    common
    core
    dhcp
    dns
    ebackup
    firewall
    ftp
    ids
    jabber
    l7-protocols
    mail
    mailfilter
    monitor
    network
    ntp
    objects
    openvpn
    printers
    radius
    remoteservices
    samba
    services
    software
    squid
    trafficshaping
    usercorner
    users
    webmail
    webserver
    zarafa

When you start working on your own module, please let the Zentyal Developers
and other community members know what you are working on. This is good thing
in order to avoid overlapping (different people working on similar project)
as well as to get feedback and help when necessary. Simply start a new thread
in the Zentyal Forum when you start your project and post the advances in the
same thread or alternatively, send an e-mail to the public Zentyal Development
mailing list [#]_.
 
.. [#] <http://www.virtualbox.org/>
.. [#] <http://trac.zentyal.org/wiki/Document/Development/SVN>
.. [#] <http://lists.zentyal.org/cgi-bin/mailman/listinfo/zentyal-devel>
