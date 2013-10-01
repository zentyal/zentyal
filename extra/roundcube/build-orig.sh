#!/bin/bash

version=$1

if [ -z "$version" ]
then
    echo "Usage: $0 <version>"
    exit 1
fi

url="http://sourceforge.net/projects/roundcubemail/files/roundcubemail-dependent/$version/roundcubemail-$version-dep.tar.gz/download"

wget $url -O roundcube-$version.tar.gz

if [ ! -f "roundcube-$version.tar.gz" ]; then
    echo "tar file not found"
    exit 1
fi

gunzip roundcube-$version.tar.gz
tar xvf roundcube-$version.tar
mv roundcubemail-$version-dep roundcube_$version
tar cfz roundcube_$version.orig.tar.gz "roundcube_$version"
rm -rf "roundcube_$version"

exit 0
