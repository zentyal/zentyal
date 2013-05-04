#!/bin/bash

LOG=/var/tmp/zentyal-installer.log

plymouth message --text="Installing Zentyal core packages... Please wait."

/usr/share/zenbuntu-desktop/core-install >> $LOG 2>&1
if [ $? -ne 0 ]
then
    plymouth message --text="Installation failed. Press <ESC> to see details."
    exit 1
fi

plymouth message --text="Core packages installed. Continuing first boot..."

if [ -d /usr/share/zenbuntu-desktop ]
then
    /usr/share/zenbuntu-desktop/x11-setup >> $LOG 2>&1

    mv /usr/share/zenbuntu-desktop/second-boot.sh /etc/rc.local

    initctl emit zentyal-lxdm
fi

exit 0
