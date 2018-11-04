#!/bin/bash

# If Zentyal is already installed...
if ! [ -f '/var/lib/zentyal/.first' ]
then
    # Disable auto login once installation is done
    sed -i "s/.*autologin=.*/# autologin=nobody/" /etc/lxdm/default.conf

    # Remove temporal local repository
    sed -i "/deb.*file.*zentyal-packages/d" /etc/apt/sources.list
    rm -rf /var/tmp/zentyal-packages
    apt-get clean

    # Restore default rc.local and execute it
    cp /usr/share/zenbuntu-core/rc.local /etc/rc.local
    . /etc/rc.local
fi

exit 0
