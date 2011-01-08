=========================
Creating our first module
=========================

Installing the necessary stuff
==============================

We will be using zmoddev, a collection of convenience scripts that will help
us create the structure and basic files for a Zentyal module.

You will need to add the following repository to your APT sources::

    deb http://ppa.launchpad.net/zentyal/2.0-extras/ubuntu lucid main

And then install this package by running the following command::

    sudo apt-get install zmoddev

Selecting a service
===================

During this tutorial we will create a module to manage an HTTP server, in this case, it will be Apache2.

There is already an implementation of an Apache module in Zentyal. However, this is a step-by-step tutorial which will simplify some things for the sake of clarity. We usually pick this service for documentation purposes as it allows us to explain most of the features in Zentyal.

In our first iteration we will create a module that will allow the user to just choose which port Apache will listen on.

Let's get it started.

Scaffolding
===========

First of all we need to create all the scaffolding for a new module. This is where emoddev comes in handy.

Run the following command::

    zentyal-moddev-create --module-name apache2 --main-class Apache2 --version 0.1

The above command will create a directory called apache2 with all the files that compose an Zentyal module.

Go into this new directory::

    cd apache2

.. _building-module:

Building and installing the module
==================================

Let's build the package to install our first module by running::

    dpkg-buildpackage -uc -us

The above command will build a debian package with your new module. You will find the package in the parent directory. You will need to install this package on the machine you have installed Zentyal using dpkg::

    sudo dpkg -i ebox-apache2_0.1_all.deb

Fire up your browser to check the results of this operation. You should now see a new menu entry called Apache2. Click on this entry. You will see something like this:

.. image:: images/just-installed.png
