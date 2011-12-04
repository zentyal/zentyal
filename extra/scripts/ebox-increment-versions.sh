#!/bin/sh

# Increases the version in configure.ac and replaces HEAD in the changelogs
# This is done only on modules with changes in the changelog

# TODO: If a version like 1.4 is passed as argument, replace all instead
# of increasing it no matter if it has changes.

packages="libebox `ls client`"

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
    if head -1 ChangeLog | grep -q HEAD
    then
        current_version=`head -1 configure.ac|cut -d'[' -f3 | cut -d']' -f1`
        major=`echo $current_version | cut -d'.' -f1-2`
        minor=`echo $current_version | cut -d'.' -f3`
        new_version="$major.`expr $minor + 1`"
        echo $new_version
        version=`head -1 ChangeLog`
        sed -i "s/$current_version/$new_version/" configure.ac
        sed -i "s/HEAD/$new_version/" ChangeLog
    fi
    cd $cwd
done
