#!/bin/bash

plymouth message --text="Installing Zentyal core packages... Please wait."

/usr/share/zenbuntu-desktop/core-install
if [ $? -ne 0 ]
then
    plymouth message --text="Installation failed. Press <ESC> to see details."
    exit 1
fi

plymouth message --text="Core packages installed. Continuing first boot..."

/usr/share/zenbuntu-desktop/x11-setup

mv /usr/share/zenbuntu-desktop/second-boot.sh /etc/rc.local

initctl emit zentyal-lxdm

exit 0
