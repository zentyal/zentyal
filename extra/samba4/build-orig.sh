#!/bin/bash

version=$1
base_url="ftp://ftp.samba.org/pub/samba"

if [ -z "$version" ]
then
    echo "Usage: $0 <version>"
    exit 1
fi

if [[ "$version" =~ "rc" ]]; then
    base_url="$base_url/rc"
else
    base_url="$base_url/stable"
fi

tar_file="$base_url/samba-$version.tar.gz"
asc_file="$base_url/samba-$version.tar.asc"

wget "$tar_file"
wget "$asc_file"

if [ ! -f "samba-$version.tar.gz" ]; then
    echo "tar file not found"
    exit 1
fi

if [ ! -f "samba-$version.tar.asc" ]; then
    echo "asc file not found"
    exit 1
fi

gunzip samba-$version.tar.gz
gpg --verify samba-$version.tar.asc
tar xvf samba-$version.tar
mv samba-$version samba4_$version
rm samba-$version.tar.asc samba-$version.tar
tar cfz samba4_$version.orig.tar.gz "samba4_$version"
rm -rf "samba4_$version"

exit 0
