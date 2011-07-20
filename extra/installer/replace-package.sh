#!/bin/bash

PKG=$1

if [ -z $PKG ] || ! [ -f $PKG ]
then
    echo package does not exist
    exit 1
fi

name=`basename $PKG | cut -d_ -f1`

rm extras-{i386,amd64}/${name}_*.deb
cp $PKG extras-i386
cp $PKG extras-amd64
