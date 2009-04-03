#!/bin/sh

SOURCES="/etc/apt/sources.list"

if ! grep -q ebox-unstable $SOURCES
then
    echo "deb http://ppa.launchpad.net/ebox-unstable/ubuntu intrepid main" >> $SOURCES
#    echo "deb http://broken/ebox-unstable/intrepid ./" >> $SOURCES
fi    
