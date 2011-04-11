===============
Getting started
===============

Intro
=====

This tutorial is meant to be an easy-to-follow guide to developing new modules
for Zentyal and extending the features of the existing ones.

We will show you the necessary steps to implement a full-fledged Zentyal
module, using an incremental development approach.

The Zentyal development framework has a clear goal: make life easier for those
developers who want to provide an UI to manage Linux services integrated with
other services on the same machine. We want developers to focus only on adding
functionality for the service their modules manage. The framework tries hard
to keep you away from messing with HTML, CGIs and so on.

Requirements
============

You should be familiar with a programming language. Although modules are
written in Perl, the data structures and syntax should be easily understood by
newcomers.

If you want to try out the code, you will need a machine running Ubuntu Lucid
with Zentyal installed. We strongly recommend the use of virtual machines for
Zentyal development. You can use VirtualBox [#]_ with a clean Zentyal
installation to start up. It's always a good practice to use the snapshot
capabilities to keep a clean environment where to go back.

Learning to build from source
=============================

One of the first step to get involved into a project development is to be able
to build the software from the source. You can download Zentyal source code
from our Subversion repository [#]_. Let's see how to fetch Zentyal source and
build everything from scratch.

First install some basic development tools::

    sudo apt-get install --no-install-recommends \
    subversion autoconf automake gettext dpkg-dev devscripts cdbs liberror-perl

Then you have to fetch *trunk* which is the main development branch. You will also
have to download the *script* directory too::

    mkdir ~/zentyal ; cd ~/zentyal
    svn co http://svn.zentyal.org/zentyal/trunk/
    svn co http://svn.zentyal.org/zentyal/scripts/

Now add the *ebox-package* script to your PATH::

    mkdir ~/bin ; cd ~/bin
    ln -s ~/zentyal/scripts/ebox-package .

After spawning a new shell to add the new *bin* directory to your PATH, if you
go to the *trunk* directory, you will be able to start building the Zentyal
packages::

    cd ~/zentyal/trunk
    ebox-package libebox
    ebox-package ebox
    ebox-package software
    ebox-package network
    ebox-package services
    ebox-package objects
    ebox-package firewall

... and so on. In order to avoid a dependency mess, we will install these
packages on top of an existing Zentyal installation (probably on a virtual
machine) with the modules you have built and you are about to install already
installed::

    scp debs-ppa/*.deb user@zentyal-dev:
    ssh user@zentyal-dev
    sudo dpkg -i --force-all *.deb

It's a general recommendation to install only the modules you are working with
and do it first from :guilabel:`Software management` or via *apt-get* to
avoid dependency problems.

You can find all Zentyal modules inside *client/* directory::

    $ ls -1 client/
    antivirus
    asterisk
    ca
    dhcp
    dns
    ebackup
    ebox
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
    usersandgroups
    webmail
    webserver
    zarafa
 
.. [#] <http://www.virtualbox.org/>
.. [#] <http://trac.zentyal.org/wiki/Document/Development/SVN>
