#!/bin/bash -e
# DFSG-Clean a Samba 4 source tarball

srcdir="$1"

if [ -z "$srcdir" ]; then
    srcdir="."
fi

if [ ! -d "$srcdir/source4" ]; then
    echo "Usage: $0 SRCDIR"
    exit 1
fi

pushd $srcdir/source4 > /dev/null
rm -rf heimdal/lib/wind/*.txt
rm -rf ldap_server/devdocs
rm -rf selftest/provisions/alpha13
popd > /dev/null

pushd $srcdir > /dev/null
rm -f script/librelease.sh
popd > /dev/null

exit 0
