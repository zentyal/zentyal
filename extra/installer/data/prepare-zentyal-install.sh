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

if [ -f /media/cdrom/zentyal/commercial-edition ]
then
    mkdir -p /var/lib/zentyal/
    touch /var/lib/zentyal/.commercial-edition
    echo ACTIVATION-REQUIRED > /var/lib/zentyal/.license
fi

sed -i 's/#GRUB_HIDDEN_TIMEOUT=0/GRUB_HIDDEN_TIMEOUT=0/' /etc/default/grub
sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 net.ifnames=0 biosdevname=0"/' /etc/default/grub
update-grub

sed -i '2s/.*\t/127.0.1.1\t/' /etc/hosts

### CUSTOM_ACTION ###

sync

exit 0
