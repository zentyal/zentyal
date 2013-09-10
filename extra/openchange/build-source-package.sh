#!/bin/bash

package=$1
version=$2
rev=$3

if [ -z "$version" ]
then
    echo "Usage: $0 [SOPE|SOGo|openchange] <version> [rev]"
    exit 1
fi

if [ "$package" = "openchange" ] && [ "$version" != "latest" ]; then
    echo "We only support 'latest' version for openchange."
    exit 1
fi

if [ -z "$rev" ]
then
    rev=1
fi

package_lc=${package,,}
BUILD_DIR=/tmp/build-${package_lc}-$$
CWD=`pwd`

SRC="${package_lc}_$version.orig.tar.gz"

if [ "$package" = "openchange" ]; then
    generated=`ls -tr openchange_*.orig.tar.gz |tail -1`
    if [ ! -f $generated ]; then
        ./build-orig.sh $package $version
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
    SRC=$generated
    version=${generated/${package}_/}
    version=${version/.orig.tar.gz/}
    echo $version
else
    if ! [ -f $SRC ]; then
        ./build-orig.sh $package $version
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
fi

if ! [ -f $SRC ] ; then
    echo "Unable to get the origin tar ball for $package / $version."
    exit 1
fi

mkdir $BUILD_DIR
ln -sf $CWD/$SRC $BUILD_DIR/$SRC

pushd $BUILD_DIR
tar xzf $CWD/$SRC
cd ${package_lc}-$version
cp -r $CWD/debian-${package_lc} debian
dch -b -v "$version-zentyal$rev" -D 'precise' --force-distribution 'New upstream release'
cp debian/changelog $CWD/debian-${package_lc}/

ppa-build.sh
popd

mv $BUILD_DIR/${package_lc}_*.{debian.tar.gz,dsc,changes} .
rm -rf $BUILD_DIR
