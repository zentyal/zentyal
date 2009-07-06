#!/bin/sh

SOURCES="/etc/apt/sources.list"


if ! grep -q ebox-unstable $SOURCES
then
    echo "deb http://ppa.launchpad.net/ebox-unstable/ubuntu hardy main" >> $SOURCES
    echo "deb http://ppa.launchpad.net/ebox-unstable/seville/ubuntu hardy main " >> $SOURCES
fi

if ! grep -q seville $SOURCES
then
    echo "deb http://ppa.launchpad.net/ebox-unstable/seville/ubuntu hardy main " >> $SOURCES
fi

if ! grep -q "10.6.7.1" $SOURCES
then
    echo "deb http://10.6.7.1/ebox ./" >> $SOURCES
fi
