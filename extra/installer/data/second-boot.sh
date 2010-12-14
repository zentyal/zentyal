#!/bin/sh

# If Zentyal is already installed...
if ! [ -f '/var/lib/ebox/.first' ]
then
    # Disable auto login once installation is done
    sed -i "s/.*autologin=.*/# autologin=nobody/" /etc/lxdm/default.conf

    # Remove temporal local repository
    sed -i "/deb file.*ebox-packages/d" /etc/apt/sources.list

    # Restore original rc.local and clean stuff
    mv /var/tmp/ebox/rc.local /etc/rc.local
    rm -rf /var/tmp/ebox
fi

initctl emit zentyal-lxdm

exit 0
