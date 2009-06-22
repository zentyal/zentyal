#!/bin/sh

# Wait for ebox start
sleep 10

# wipe out current network configuration
rm -rf /var/lib/ebox/gconf/ebox/modules/network
pkill gconf

# import configuration
/usr/share/ebox-network/ebox-netcfg-import
