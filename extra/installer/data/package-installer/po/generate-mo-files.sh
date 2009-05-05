#!/bin/sh

DEST=$1

[ -d locale ] || mkdir locale

for i in `cat LINGUAS`
do
    DIR=$DEST/locale/$i/lC_MESSAGES
    [ -d $DIR ] || mkdir -p $DIR
    msgfmt -o $DIR/ebox-package-installer.mo $i.po
done
