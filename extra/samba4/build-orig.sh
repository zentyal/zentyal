#!/bin/bash

version=$1

if [ -z "$version" ]
then
    echo "Usage: $0 <version>"
    exit 1
fi

wget ftp://ftp.samba.org/pub/samba/samba-$version.tar.gz
wget ftp://ftp.samba.org/pub/samba/samba-$version.tar.asc

gunzip samba-$version.tar.gz
gpg --verify samba-$version.tar.asc
tar xvf samba-$version.tar
mv samba-$version samba4_$version
rm samba-$version.tar.asc samba-$version.tar
tar cfz samba4_$version.orig.tar.gz "samba4_$version"
rm -rf "samba4_$version"

exit 0
