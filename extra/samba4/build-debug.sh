#!/bin/bash

version=$1

if [ -z "$version" ]
then
    echo "Usage: $0 <version>"
    exit 1
fi

apt-get install --yes --force-yes build-essential debhelper libacl1-dev libattr1-dev libblkid-dev libgnutls-dev libreadline-dev python-dev python-dnspython gdb pkg-config libpopt-dev libldap2-dev dnsutils libbsd-dev attr docbook-xsl libcups2-dev libmagic-dev libpcre3-dev libclamav-dev libpam0g-dev libgpg-error-dev libgcrypt11-dev libkeyutils-dev libdm0-dev zlib1g-dev git

source=samba-$version.tar.gz

[ -f $source ] || wget ftp://ftp.samba.org/pub/samba/$source

dir=samba4_$version
if [ -d $dir]
then
    cd $dir
else
    tar xzf $source
    cd $dir
    git init
fi

./configure.developer --prefix=/opt/samba4 --sysconfdir=/etc/samba --bundled-libraries=ALL --enable-zavs
make
make install
