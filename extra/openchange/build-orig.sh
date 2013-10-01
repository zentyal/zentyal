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

if [ "$package" = "openchange" ] && [ "$version" = "latest" ]; then
    if [ ! -d openchange-master ]; then
        git clone https://github.com/Zentyal/openchange.git openchange-master
    else
        pushd openchange-master > /dev/null 2>&1
        git pull > /dev/null
        popd > /dev/null 2>&1
    fi
    pushd openchange-master > /dev/null 2>&1
    version=`git describe master --tags`
    version=${version/$package-/}
    generated=${package_lc}_$version.orig.tar.gz
    if [ ! -f $generated ]; then
        git archive master --prefix=${package_lc}-$version/ | gzip > ../$generated
    else
        echo "Skip generating orig $generated"
    fi
    popd > /dev/null 2>&1
elif [[ ("$package" = "SOGo" && "$version" = "latest" ) || ("$package" = "SOPE" && "$version" = "latest") ]]; then
    if [ ! -d zentyal-exchange ]; then
        git clone https://github.com/Zentyal/zentyal-exchange.git zentyal-exchange
    else
        pushd zentyal-exchange > /dev/null 2>&1
        git pull > /dev/null
        popd > /dev/null 2>&1
    fi
    pushd zentyal-exchange/$package_lc > /dev/null 2>&1
    source Version
    version="$MAJOR_VERSION.$MINOR_VERSION"
    if [ -n "$SUBMINOR_VERSION" ]; then
        version="$version.$SUBMINOR_VERSION"
    fi
    generated=${package_lc}_$version.orig.tar.gz
    if [ ! -f $generated ]; then
        git archive master . --prefix=${package_lc}-$version/ | gzip > ../../$generated
    else
        echo "Skip generating orig $generated"
    fi
    popd > /dev/null 2>&1
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
    generated=${package_lc}_$version.orig.tar.gz
    rm $package-$version.tar.gz
    tar cfz $generated "${package_lc}-$version"
    rm -rf "${package_lc}-$version"
fi

exit 0
