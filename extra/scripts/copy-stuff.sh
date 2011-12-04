#!/bin/bash

# Kopyleft (K) 2009
# All rights reversed

# PM files
files=$(svn status |grep -v ^?|grep -v ^D| grep '\.pm' |cut -c8-)
for file in $files; do
    if echo $file | grep -q 'CGI'; then
        dstFile=$(echo $file | cut -c14-)
        mod=$(basename $(pwd))
        mod=$(echo $mod | cut -c1 | tr [:lower:] [:upper:])$(echo $mod | cut -c2-)
        cp $file ~/ebox-devel-host/usr/share/perl5/EBox/CGI/$mod/$dstFile
    else
        dstFile=$(echo $file | cut -c5-)
        cp $file ~/ebox-devel-host/usr/share/perl5/$dstFile
    fi
done

# Stubs files
files=$(svn status |grep -v ^?|grep -v ^D| grep '\.mas' |cut -c8-)
for file in $files; do
    currentDir=$(basename $(pwd))
    if echo $file | grep -q 'stubs'; then
        dstFile=$(echo $file | cut -c7-)
        cp $file ~/ebox-devel-host/usr/share/ebox/stubs/$currentDir/$dstFile
    elif echo $file | grep -q 'templates'; then
        dstFile=$(echo $file | cut -c15-)
        cp $file ~/ebox-devel-host/usr/share/ebox/templates/$currentDir/$dstFile
    fi
done

# test files
files=$(svn status |grep -v ^?|grep -v ^D| grep '\.t' |cut -c8-)
for file in $files; do
    dstFile=$(basename $file)
    cp $file ~/ebox-devel-host/tmp/$dstFile
done
