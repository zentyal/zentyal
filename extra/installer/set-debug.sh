#!/bin/bash

. ./build_cd.conf

. ./debug.vars

cp $DATA_DIR/zentyal-debug.seed.template $DATA_DIR/zentyal-debug.seed

DEFINED_VARS=no

function set_var()
{
    varname=$1
    eval varvalue=\$$varname

    if [ -n "$varvalue" ]
    then
        sed -i "s/$varname/$varvalue/g" $DATA_DIR/zentyal-debug.seed
        DEFINED_VARS=yes
    else
        sed -i "/.*$varname.*/d" $DATA_DIR/zentyal-debug.seed
    fi
}

set_var DISABLE_AUTOCONFIG
set_var STATIC_IP
set_var STATIC_DNS
set_var STATIC_GW
set_var HOSTNAME_INSTALL
set_var ADMIN_USER
set_var ADMIN_PASS
set_var REMOTE_USER
set_var REMOTE_PASS
set_var HOSTNAME_RECOVER

if [ "$DEFINED_VARS" == "yes" ]
then
    touch DEBUG_MODE
    exit 0
else
    echo "You need to edit debug.vars!"
    exit 1
fi
