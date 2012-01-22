#!/bin/bash

test -r build_cd.conf || exit 1
. ./build_cd.conf

cwd=`pwd`
BUILD_DIR="$cwd/../build-installer/$ZENTYAL_ISO_NAME"

mkdir -p $BUILD_DIR

for i in build_cd.conf sources.list
do
    cp $i $BUILD_DIR
done

sed -i "s|BASE_DIR=.*|BASE_DIR=$BUILD_DIR|g" $BUILD_DIR/build_cd.conf

for i in apt-ftparchive sources.list
do
    cp -r $i $BUILD_DIR
done
mkdir $BUILD_DIR/indices

for i in data images build_cd.sh generate_extras.sh setup-base-cd-image.sh \
         list-duplicated.sh list-not-installed.sh zenbuntu-desktop
do
    ln -s $cwd/$i $BUILD_DIR/$i
done

mkdir $BUILD_DIR/scripts
for i in $cwd/scripts/*
do
    ln -s $i $BUILD_DIR/scripts/`basename $i`
done

echo "Build directory created."
echo
echo "Execute the following to generate it:"
echo "cd $BUILD_DIR"
echo "./setup-base-cd-image.sh [i386|amd64]"
echo "./generate_extras.sh [i386|amd64]"
echo "./build_cd.sh [i386|amd64]"

# TODO: fix list-duplicated and change it to remove-duplicated
# to allow automatic use
# For the list of not installed packages maybe we can also
# detect which packages on the installer are not present
# on the chroot (excluding the base system / installer ones)

# TODO: autogenerate a one-step script?

exit 0
