#!/bin/sh

DOMAIN=$1

VIRSH=`whereis -b virsh | cut -f2 -d' '`

while true; do
	$VIRSH list | grep $DOMAIN
	if [ $? -eq 0 ]
    then
	    sleep 1
    else        
        exit 0
	fi
done > /dev/null
