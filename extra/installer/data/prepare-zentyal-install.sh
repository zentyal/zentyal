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

echo "FRAMEBUFFER=y" > /etc/initramfs-tools/conf.d/splash
update-initramfs -u

sed -i 's/#GRUB_HIDDEN_TIMEOUT=0/GRUB_HIDDEN_TIMEOUT=0/' /etc/default/grub
sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 net.ifnames=0 biosdevname=0"/' /etc/default/grub
SIZE=$(sed 's/,/x/' /sys/class/graphics/fb0/virtual_size)
echo "GRUB_GFXMODE=$SIZE" >> /etc/default/grub
echo "GRUB_GFXPAYLOAD_LINUX=keep" >> /etc/default/grub
update-grub

### CUSTOM_ACTION ###

sync

exit 0
