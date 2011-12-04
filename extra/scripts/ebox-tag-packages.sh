#!/bin/bash

# Generates the commands to tag the package names passed as commandline arguments

SERIES="2.0-series"

packages=$@

cwd=`pwd`
for i in $packages
do
    if [ "$i" == "libebox" ]
    then
        dir=common/libebox
    else
        dir=client/$i
    fi
    cd $dir
    name=`basename $dir`
    version=`head -1 ChangeLog`
    echo "svn copy https://svn.zentyal.org/zentyal/trunk/$dir https://svn.zentyal.org/zentyal/tags/$SERIES/$name-$version -m 'tagging $name $version'"
    cd $cwd
done
