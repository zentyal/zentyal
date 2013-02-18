#!/bin/bash

version=$1
rev=$2

if [ -z "$version" ]
then
    echo "Usage: $0 <version> [rev]"
    exit 1
fi

if [ -z "$rev" ]
then
    rev=1
fi

BUILD_DIR=/tmp/build-samba4-$$
CWD=`pwd`

SAMBA_SRC="samba4_$version.orig.tar.gz"

if ! [ -f $SAMBA_SRC ]
then
    ./build-orig.sh $version
fi

mkdir $BUILD_DIR
ln -sf $CWD/$SAMBA_SRC $BUILD_DIR/$SAMBA_SRC

pushd $BUILD_DIR
tar xzf $CWD/$SAMBA_SRC
cd samba4_$version
cp -r $CWD/debian .
dch -b -v "$version-zentyal$rev" -D 'precise' --force-distribution 'New upstream release'
cp debian/changelog $CWD/debian/

pdebuild
popd

cp /var/cache/pbuilder/precise-i386/result/*.deb .
rm -rf $BUILD_DIR
