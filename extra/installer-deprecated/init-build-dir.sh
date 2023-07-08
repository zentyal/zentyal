#!/bin/bash

test -r build_cd.conf || exit 1
. ./build_cd.conf

cwd=`pwd`
BUILD_DIR="$cwd/../build-installer/$ZENTYAL_ISO_NAME"

mkdir -p $BUILD_DIR

for i in build_cd.conf sources.list debug.vars
do
    cp $i $BUILD_DIR
done

sed -i "s|BASE_DIR=.*|BASE_DIR=$BUILD_DIR|g" $BUILD_DIR/build_cd.conf

for i in apt-ftparchive sources.list
do
    cp -r $i $BUILD_DIR
done
mkdir $BUILD_DIR/indices

for i in autobuild build_cd.sh generate_extras.sh setup-base-cd-image.sh extract-core-deps.sh \
         regen_iso.sh list-duplicated.sh list-not-installed.sh replace-debs-ppa.sh \
         set-debug.sh zenbuntu-core zenbuntu-desktop zinstaller-headless data images
do
    ln -s $cwd/$i $BUILD_DIR/$i
done

mkdir $BUILD_DIR/scripts
for i in $cwd/scripts/*
do
    ln -s $i $BUILD_DIR/scripts/`basename $i`
done

for arch in $ARCHS
do
    if [ -f $cwd/$UBUNTU_ISO_NAME-$arch.iso ]
    then
        ln -f $cwd/$UBUNTU_ISO_NAME-$arch.iso $BUILD_DIR/
    fi

    if [ -d $EXTRAS_CUSTOM_DIR_BASE-$arch ]
    then
        cp -r $EXTRAS_CUSTOM_DIR_BASE-$arch $BUILD_DIR
    fi
done

if [ -d $EXTRAS_CUSTOM_DIR_BASE-all ]
then
    cp -r $EXTRAS_CUSTOM_DIR_BASE-all $BUILD_DIR
fi

cp -r $cwd/$CUSTOM_DIR_BASE $BUILD_DIR/

echo "Build directory created at $BUILD_DIR"

exit 0
