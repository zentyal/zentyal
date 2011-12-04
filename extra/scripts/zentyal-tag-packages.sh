#!/bin/bash

# Generates the commands to tag the package names passed as commandline arguments

SERIES="2.2-series"

packages=$@

cwd=`pwd`
for i in $packages
do
    name=$i
    version=`head -1 $i/ChangeLog`
    echo "svn copy https://svn.zentyal.org/zentyal/trunk/main/$i https://svn.zentyal.org/zentyal/tags/$SERIES/$name-$version -m 'tagging $name $version'"
    cd $cwd
done
