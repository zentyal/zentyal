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

    mv /usr/share/zenbuntu-core/second-boot.sh /etc/rc.local

    # Restore default lxdm auto-startup
    rm -f /etc/init/lxdm.override

    start lxdm
else
    URL=$(/usr/share/zenbuntu-core/get-zentyal-url)
    plymouth message --text="Zentyal interface at $URL (Alt+F2 for login shell)"

    mv /usr/share/zenbuntu-core/second-boot.sh /etc/rc.local

    plymouth --wait
fi

exit 0
