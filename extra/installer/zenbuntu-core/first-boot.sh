#!/bin/bash

LOG=/var/tmp/zentyal-installer.log

plymouth message --text="Installing Zentyal core packages... Please wait."

/usr/share/zenbuntu-core/core-install >> $LOG 2>&1
if [ $? -ne 0 ]
then
    plymouth message --text="Installation failed. Press <ESC> to see details."
    exit 1
fi

if [ -d /usr/share/zenbuntu-desktop ]
then
    plymouth message --text="Core packages installed. Continuing first boot..."

    /usr/share/zenbuntu-desktop/x11-setup >> $LOG 2>&1

    mv /usr/share/zenbuntu-core/second-boot.sh /etc/rc.local

    initctl emit zentyal-lxdm
else
    URL=$(/usr/share/zenbuntu-core/get-zentyal-url)
    plymouth message --text="Zentyal interface at $URL (Alt+F2 for login shell)"

    mv /usr/share/zenbuntu-core/second-boot.sh /etc/rc.local

    plymouth --wait
fi

exit 0
