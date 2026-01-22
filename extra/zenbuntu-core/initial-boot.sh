#!/bin/bash

# If Zentyal is already installed...
if ! [ -f '/var/lib/zentyal/.first' ]
then
    # Disable auto login once installation is done
    sed -i "s/.*autologin=.*/# autologin=nobody/" /etc/lxdm/default.conf

    # Remove temporal local repository
    if [ -f '/etc/apt/sources.list.d/zentyal-temporal.sources' ]
    then
        rm -f /etc/apt/sources.list.d/zentyal-temporal.sources
        rm -rf /var/tmp/zentyal-packages/
        apt clean
    fi

    # Remove Zentyal initial directory
    if [ -d '/var/zentyal-init/' ]
    then
        rm -rf /var/zentyal-init/
    fi

    if [ -f '/etc/apt/sources.list.d/ubuntu.sources.curtin.orig' ]
    then
        rm -f /etc/apt/sources.list.d/ubuntu.sources.curtin.orig
    fi

    # Restore default rc.local and execute it
    cp /usr/share/zenbuntu-core/rc.local /etc/rc.local
    . /etc/rc.local
fi

exit 0
