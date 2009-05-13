#!/bin/bash

INSTALLER=ebox-installer

cp /tmp/motd /etc/motd

cp /etc/rc.local /var/tmp
cp /tmp/$INSTALLER /etc/rc.local

# Copy locale
cp /tmp/locale.gen /var/tmp
# Copy .mo files
cp -r /tmp/locale /usr/share/

cp /tmp/enable-all-modules.pl /var/tmp
cp -r /tmp/package-installer/* /var/tmp/
