#!/bin/sh

# Generates the commands to tag the packaging of the modules
# passed as commandline arguments

SERIES="debian/hardy"

packages=$@

cwd=`pwd`
for i in $packages
do
    dir=$i
    cd $dir
    name=`basename $dir`
    version=`head -1 changelog | cut -d'(' -f2 | cut -d')' -f1 | cut -d'-' -f1`
    echo "svn copy https://svn.ebox-platform.com/ebox-platform/packaging/$SERIES/trunk/$dir https://svn.ebox-platform.com/ebox-platform/packaging/$SERIES/tags/$name-$version -m 'tagging packaging of $name $version'"
    cd $cwd
done
