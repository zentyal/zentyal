#!/bin/bash

test -r build_cd.conf || exit 1
. ./build_cd.conf

SELECTED_ARCH=$1

METAPACKAGES_DIR=$SVN_ROOT/extra/zentyal-metapackages

EXPORT_DIR=/tmp/zentyal-installer-$$/
BUILD_DIR=${EXPORT_DIR}/zentyal-metapackages

mkdir -p $EXPORT_DIR
svn export $METAPACKAGES_DIR $BUILD_DIR

cd $BUILD_DIR
dpkg-buildpackage
cd -

for ARCH in $ARCHS
do
    if [ "$ARCH" != "$SELECTED_ARCH" ]
    then
        continue
    fi

    EXTRAS_DIR="$EXTRAS_DIR_BASE-$ARCH"
    cd $EXTRAS_DIR
    for i in all gateway infrastructure security office communication
    do
        rm ebox-${i}_*.deb zentyal-${i}_*.deb
    done
    cp $EXPORT_DIR/*.deb $EXTRAS_DIR/
    cd -
done

rm -rf $EXPORT_DIR
