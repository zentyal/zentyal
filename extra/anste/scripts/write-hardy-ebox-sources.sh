#!/bin/sh

SOURCES="/etc/apt/sources.list"


if ! grep -q "1.3" $SOURCES
then
    echo "deb http://ppa.launchpad.net/ebox/1.3/ubuntu hardy main " >> $SOURCES
fi

if ! grep -q "leela" $SOURCES
then
    echo "deb http://leela/ebox/trunk ./" >> $SOURCES
fi

if ! grep -q "10.6.7.1" $SOURCES
then
    echo "deb http://10.6.7.1/ebox ./" >> $SOURCES
fi
