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

# copy *.deb files from CD to hard disk
PKG_DIR=/var/tmp/ebox-packages
mkdir $PKG_DIR
list=`cat /tmp/extra-packages.list`
packages=`LANG=C apt-get install $list --simulate|grep ^Inst|cut -d' ' -f2`
for p in $packages
do
    char=$(echo $p | cut -c 1)
    cp /cdrom/pool/main/{$char,lib$char}/*/${p}_*.deb $PKG_DIR 2> /dev/null
    cp /cdrom/pool/extras/${p}_*.deb $PKG_DIR 2> /dev/null
done

exit 0
