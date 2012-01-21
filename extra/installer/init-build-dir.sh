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

for i in apt-ftparchive indices sources.list
do
    cp -r $i $BUILD_DIR
done

for i in data images scripts zenbuntu-desktop build_cd.sh generate_extras.sh \
         list-duplicated.sh setup-base-cd-image.sh list-not-installed.sh
do
    ln -s $cwd/$i $BUILD_DIR/$i
done

echo "Build directory created."
echo
echo "Execute the following to generate it:"
echo "cd $BUILD_DIR"
echo "./setup-base-cd-image.sh [i386|amd64]"
echo "./generate_extras.sh [i386|amd64]"
echo "./build_cd.sh [i386|amd64]"

# TODO: autogenerate a one-step script?

exit 0
