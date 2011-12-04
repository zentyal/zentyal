#!/bin/bash

# Change this with your PPA key ID
KEY_ID="19AD31B8"

EXPORT_DIR=../debs-ppa/
[ -d $EXPORT_DIR ] || mkdir $EXPORT_DIR

rm -rf $EXPORT_DIR/zentyal-desktop

svn export ../ubuntu $EXPORT_DIR/zentyal-desktop
svn export ../common $EXPORT_DIR/zentyal-desktop/common

cd $EXPORT_DIR/zentyal-desktop

dpkg-buildpackage -k$KEY_ID -S -sa

sed -i 's/+lucid) lucid;/+maverick) maverick;/g' debian/changelog
sed -i 's/unison/unison2.27.57/g' debian/control
dpkg-buildpackage -k$KEY_ID -S -sa

cd -

rm -rf $EXPORT_DIR/zentyal-desktop
