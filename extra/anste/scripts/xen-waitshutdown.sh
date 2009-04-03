#!/bin/sh

DOMAIN=$1

XM=`whereis -b xm | cut -f2 -d' '`

while true; do
	$XM list $DOMAIN
	if [ $? -eq 0 ]
    then
	    sleep 1
    else        
        exit 0
	fi
done > /dev/null
