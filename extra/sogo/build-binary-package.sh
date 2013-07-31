#!/bin/bash

package=$1
version=$2
rev=$3

if [ -z "$version" ]
then
    echo "Usage: $0 [SOPE|SOGo] <version> [rev]"
    exit 1
fi

if [ -z "$rev" ]
then
    rev=1
fi

package_lc=${package,,}
BUILD_DIR="/tmp/build-${package_lc}-$$"
CWD=`pwd`

SRC="${package_lc}-$version.orig.tar.gz"

if ! [ -f $SRC ]
then
    ./build-orig.sh $package $version
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

mkdir $BUILD_DIR
ln -sf $CWD/$SRC $BUILD_DIR/$SRC

pushd $BUILD_DIR
tar xzf $CWD/$SRC
cd ${package_lc}-$version
cp -r $CWD/debian-${package_lc} debian
dch -b -v "$version-zentyal$rev" -D 'precise' --force-distribution 'New upstream release'
cp debian/changelog $CWD/debian-${package_lc}/

pdebuild
popd

cp /var/cache/pbuilder/precise-i386/result/*.deb .
rm -rf $BUILD_DIR
