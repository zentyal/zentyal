#!/bin/bash

# Workaround for broken /etc/hosts when there is no domain
sed -i 's/127.0.1.1.*(null)/127.0.1.1/' /etc/hosts

# copy *.deb files from CD to hard disk
PKG_DIR=/var/tmp/zentyal-packages
mkdir $PKG_DIR
files=`find /media/cdrom/pool -name '*.deb'`
for file in $files
do
    cp $file $PKG_DIR 2> /dev/null
done

if [ -f /tmp/RECOVER_MODE ]
then
    # Set DR flag for second stage
    DISASTER_FILE=/var/tmp/.zentyal-disaster-recovery
    touch $DISASTER_FILE
    chown :admin $DISASTER_FILE
    chown g+w $DISASTER_FILE
fi

# Force update of grub before reboot
dpkg-reconfigure zenbuntu-core

### CUSTOM_ACTION ###

sync

exit 0
