#!/bin/bash

INSTALLER=ebox-installer

# replace motd
cp /tmp/motd /etc/motd.tail

# put in place the installer
cp /etc/rc.local /var/tmp/
cp /tmp/$INSTALLER /etc/rc.local

# copy locale.gen
cp /tmp/locale.gen /var/tmp/
# copy .mo files
cp -r /tmp/locale /usr/share/

# copy installer files
cp -r /tmp/package-installer/* /var/tmp/
