#!/bin/bash

LOG=/var/tmp/zentyal-installer.log

plymouth message --text="Installing Zentyal core packages... Please wait."

/usr/share/zenbuntu-core/core-install >> $LOG 2>&1
if [ $? -ne 0 ]
then
    plymouth message --text="Installation failed. Press <ESC> to see details."
    plymouth --wait
    exit 1
fi

if [ -d /usr/share/zenbuntu-desktop ]
then
    plymouth message --text="Core packages installed. Continuing first boot..."

    /usr/share/zenbuntu-desktop/x11-setup >> $LOG 2>&1

    # Enable lxdm auto-startup for next boots
    systemctl enable zentyal.lxdm

    systemctl start zentyal.lxdm
fi

cp /usr/share/zenbuntu-core/second-boot.sh /etc/rc.local

exit 0
