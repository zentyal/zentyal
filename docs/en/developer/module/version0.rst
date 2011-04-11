=========================
Creating our first module
=========================

Installing the necessary stuff
==============================

To create our first module we will be using zmoddev, a collection of
convenience scripts that will help us create the structure and basic files for
a Zentyal module.

You will need to add the following repository to your APT sources in the
machine you will be working, not necessarily the Zentyal VM::

    deb http://ppa.launchpad.net/zentyal/2.1-extras/ubuntu lucid main

And then install this package by running the following command::

    sudo apt-get install zmoddev

Selecting a service
===================

During this tutorial we will create a module to manage a media streaming
server, in this case, it will be Icecast2.

In our first iteration we will create a module that will manage the service
and just allows to choose which port Icecast2 will listen on.

Let's get it started!

Scaffolding
===========

First of all we need to create all the scaffolding for a new module. Usually
this can done copying the whole folder from an other simple module, deleting
not necessary stuff and renaming namespaces, but we are going to see how to do
it in a much cooler way, using zmoddev.

Run the following command::

    zentyal-moddev-create --module-name icecast2 --main-class Icecast2 --version 0.1

The above will create a directory called icecast2 with all the files that compose
a Zentyal module.

Usually a module is composed by the following files::

    AUTHORS (people who contributed to the development of the module)
    autogen.sh (script called to generate the autotools build system)
    ChangeLog (log of all changes between versions)
    configure.ac (where you define module name, version, main class and subdirs)
    COPYING (the full license text)
    Makefile.am (subdirs to walk through when building)
    
    conf/ (configuration files for the module, settings not present in the webui)
    
    debian/ (Debian/Ubuntu packaging)
    debian/lucid/ (packaging for Lucid, every distro gets its own dir here)
    
    m4/ (m4 macros stuff for dirs and so on, nothing to change here)
    
    schemas/  (schemas to define module depends and LDAP objectClasses and attributes)
    schemas/icecast2.yaml (module depends to enable and on reconfiguration)
    
    src/ (source of the module)
    src/EBox/ (Perl source of the module)
    src/EBox/Icecast2.pm (main class of the module)
    src/EBox/Icecast2/ (contains models and composites)
    src/EBox/Icecast2/Model/ (models are forms or tables to define configuration)
    src/EBox/Icecast2/Composite/ (composites are views of multiple models)
    src/scripts/ (scripts needed by the module or helpful for the administrator)
    src/scripts/enable-module (shell script run when enabled the module)
    
    stubs/ (templates for the configuration files for the service, Icecast2 here)
    
Building and installing the module
==================================

.. image:: images/just-installed.png
