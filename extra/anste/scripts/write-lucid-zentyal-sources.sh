#!/bin/sh

SOURCES="/etc/apt/sources.list"


if ! grep -q "2.0" $SOURCES
then
    echo "deb http://ppa.launchpad.net/zentyal/2.0/ubuntu lucid main " >> $SOURCES
fi

if ! grep -q "partner" $SOURCES
then
    echo "deb http://archive.canonical.com/ubuntu lucid partner " >> $SOURCES
fi

if ! grep -q "2.1" $SOURCES
then
    echo "deb http://leela/zentyal/2.1 ./" >> $SOURCES
fi

#if ! grep -q "10.6.7.1" $SOURCES
#then
#    echo "deb http://10.6.7.1/ebox ./" >> $SOURCES
#fi

if ! grep -q "multiverse" $SOURCES
then
    echo "deb http://archive.ubuntu.com/ubuntu/ lucid multiverse" >> $SOURCES
fi
