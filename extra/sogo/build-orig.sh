#!/bin/bash

package=$1
version=$2
base_url="http://www.sogo.nu/files/downloads/SOGo/Sources/"

if [ -z "$version" ] || ([ "$package" != "SOPE" ] && [ "$package" != "SOGo" ])
then
    echo "Usage: $0 [SOPE|SOGo] <version>"
    exit 1
fi

package_lc=${package,,}
tar_file="$base_url/$package-$version.tar.gz"

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
rm $package-$version.tar.gz
tar cfz ${package_lc}-$version.orig.tar.gz "${package_lc}-$version"
rm -rf "${package_lc}-$version"

exit 0
