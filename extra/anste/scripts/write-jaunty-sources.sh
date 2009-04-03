#!/bin/sh

SOURCES="/etc/apt/sources.list"

if ! grep -q universe $SOURCES
then
    echo "deb http://en.archive.ubuntu.com/ubuntu jaunty universe" >> $SOURCES
fi
