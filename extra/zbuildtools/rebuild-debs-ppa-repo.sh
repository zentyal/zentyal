#!/bin/bash
if [ $# -eq 0 ]
then
    echo "You need to specify the folder where your repo is"
    exit
fi

if [ -d "$1" ]; then
    echo "Archiving packages"
    apt-ftparchive packages $1 > Packages
    echo "gziping packages"
    gzip -f -c Packages > $1/Packages.gz
    echo "Archiving sources"
    apt-ftparchive sources $1 > Sources
    echo "gziping sources"
    gzip -f -c Sources > $1/Sources.gz
else
    echo "The folder does not exist"
fi
