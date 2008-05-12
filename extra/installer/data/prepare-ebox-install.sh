#!/bin/bash

INSTALLER=ebox-installer

cp /tmp/$INSTALLER /etc/init.d/$INSTALLER
chmod 0755 /etc/init.d/$INSTALLER
update-rc.d $INSTALLER start  41 S .

# Copy locale 
cp /tmp/locale.gen /var/tmp
cp /tmp/enable-all-modules.pl /var/tmp
