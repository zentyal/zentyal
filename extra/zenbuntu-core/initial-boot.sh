#!/bin/bash

# If Zentyal is already installed...
if ! [ -f '/var/lib/zentyal/.first' ]
then
    # Disable auto login once installation is done
    sed -i "s/.*autologin=.*/# autologin=nobody/" /etc/lxdm/default.conf

    # Remove temporal local repository
    if [ -f '/etc/apt/sources.list.d/zentyal-temporal.list' ]
    then
        rm -f /etc/apt/sources.list.d/zentyal-temporal.list
        rm -rf /var/tmp/zentyal-packages/
        apt clean
    fi

    # Remove Zentyal initial directory
    if [ -d '/var/zentyal-init/' ]
    then
        rm -rf /var/zentyal-init/
    fi

    # Remove sources.list backup generated for Curtin
    if [ -f '/etc/apt/sources.list.curtin.old' ]
    then
        rm -f /etc/apt/sources.list.curtin.old
    fi

    # Restore default rc.local and execute it
    cp /usr/share/zenbuntu-core/rc.local /etc/rc.local
    . /etc/rc.local
fi

exit 0
