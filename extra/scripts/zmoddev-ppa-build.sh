#!/bin/bash

# Change this with your PPA key ID
KEY_ID="19AD31B8"

EXPORT_DIR=../debs-ppa/
[ -d $EXPORT_DIR ] || mkdir $EXPORT_DIR

rm -rf $EXPORT_DIR/zmoddev

svn export ../moddev $EXPORT_DIR/zmoddev

cd $EXPORT_DIR/zmoddev

./autogen.sh
dpkg-buildpackage -k$KEY_ID

cd -

rm -rf $EXPORT_DIR/zmoddev
