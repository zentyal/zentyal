#!/bin/bash

# Increases the version in configure.ac and replaces HEAD in the changelogs
# This is done only on modules with changes in the changelog

# If a version is passed as argument, replace all instead
# of increasing it no matter if it has changes.
new_version=$1
new_version_orig=$new_version

function increment
{
    dir=$1
    if head -1 ChangeLog | grep -q HEAD
    then
        current_version=`sed -n "/^[0-9]/p" ChangeLog|head -1`
        new_version=$new_version_orig
        if [ -z $new_version ]
        then
            major=`echo $current_version | cut -d'.' -f1-2`
            minor=`echo $current_version | cut -d'.' -f3`
            new_version="$major.`expr $minor + 1`"
        fi
        echo "$dir - $new_version"
        sed -i "s/HEAD/$new_version/" ChangeLog
    fi
}

cwd=`pwd`

# single package, do not iterate
if [ -f ChangeLog ]
then
    increment `basename $cwd`
    exit $?
fi

packages=`ls | grep ^[a-z] | grep -v debs-ppa`
for dir in $packages
do
    cd $dir
    increment $dir
    cd $cwd
done
