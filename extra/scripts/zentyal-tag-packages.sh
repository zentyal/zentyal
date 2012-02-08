#!/bin/bash

# Generates the commands to tag the package names passed as commandline arguments

packages=$@

cwd=`pwd`
for i in $packages
do
    name=$i
    version=`head -1 $i/ChangeLog`
    echo "git tag $i-$version && git push origin $i-$version"
    cd $cwd
done
