#!/bin/bash

# Increases the version in configure.ac and replaces HEAD in the changelogs
# This is done only on modules with changes in the changelog

# If a version is passed as argument, replace all instead
# of increasing it no matter if it has changes.
new_version=$1
new_version_orig=$new_version

packages=`ls | grep ^[a-z] | grep -v debs-ppa`

cwd=`pwd`
for dir in $packages
do
    cd $dir
    if head -1 ChangeLog | grep -q HEAD
    then
        current_version=`head -1 configure.ac|cut -d'[' -f3 | cut -d']' -f1`
        new_version=$new_version_orig
        if [ -z $new_version ]
        then
            major=`echo $current_version | cut -d'.' -f1-2`
            minor=`echo $current_version | cut -d'.' -f3`
            new_version="$major.`expr $minor + 1`"
        fi
        echo "$dir - $new_version"
        version=`head -1 ChangeLog`
        sed -i "s/$current_version/$new_version/" configure.ac
        sed -i "s/HEAD/$new_version/" ChangeLog
    fi
    cd $cwd
done
