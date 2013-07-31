#!/bin/bash

package=$1
version=$2
base_url="http://www.sogo.nu/files/downloads/SOGo/Sources/"

if [ -z "$version" ] || ([ "$package" != "SOPE" ] && [ "$package" != "SOGo" ] && [ "$package" != "openchange" ])
then
    echo "Usage: $0 [SOPE|SOGo|openchange] <version>"
    exit 1
fi

if [ "$package" = "openchange" ] && [ "$version" != "latest" ]; then
    echo "We only support 'latest' version for openchange."
    exit 1
fi

package_lc=${package,,}
tar_file="$base_url/$package-$version.tar.gz"

if [ "$package" = "openchange" ]
then
    git clone git://git.openchange.org/openchange.git openchange-master
    pushd .
    cd openchange-master
    version=`git describe master --tags`
    generated=$version.orig.tar.gz
    git archive master --prefix=$version/ | gzip > ../$generated
    popd
    rm -rf openchange-master
else
    wget "$tar_file"

    if [ ! -f "$package-$version.tar.gz" ]; then
        echo "tar file not found"
        exit 1
    fi
    tar xvfz $package-$version.tar.gz
    if [ "$package" = "SOPE" ]
    then
        mv $package ${package_lc}-$version
    else
        mv $package-$version ${package_lc}-$version
    fi
    generated=${package_lc}-$version.orig.tar.gz
    rm $package-$version.tar.gz
    tar cfz $generated "${package_lc}-$version"
    rm -rf "${package_lc}-$version"

fi

exit 0
