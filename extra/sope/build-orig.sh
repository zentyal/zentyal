#!/bin/bash

version=$1
base_url="http://www.sogo.nu/files/downloads/SOGo/Sources/"

if [ -z "$version" ]
then
    echo "Usage: $0 <version>"
    exit 1
fi


tar_file="$base_url/SOPE-$version.tar.gz"

if [ "$version" = "latest" ]
then
    if [ ! -d sope ]; then
        git clone https://github.com/inverse-inc/sope.git sope
    else
        pushd sope > /dev/null 2>&1
        git pull > /dev/null
        popd > /dev/null 2>&1
    fi
    pushd sope > /dev/null 2>&1
    source Version
    version="$MAJOR_VERSION.$MINOR_VERSION"
    if [ -n "$SUBMINOR_VERSION" ]; then
        version="$version.$SUBMINOR_VERSION"
    fi
    generated=sope_$version.orig.tar.gz
    if [ ! -f $generated ]; then
        git archive master . --prefix=sope-$version/ | gzip > ../$generated
    else
        echo "Skip generating orig $generated"
    fi
    popd > /dev/null 2>&1
else
    wget "$tar_file"

    if [ ! -f "SOPE-$version.tar.gz" ]; then
        echo "tar file not found"
        exit 1
    fi
    tar xvfz SOPE-$version.tar.gz
    mv SOPE sope-$version
    generated=sope_$version.orig.tar.gz
    rm SOPE-$version.tar.gz
    tar cfz $generated "sope-$version"
    rm -rf "sope-$version"
fi

exit 0
