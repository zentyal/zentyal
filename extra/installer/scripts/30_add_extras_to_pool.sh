#!/bin/bash

. ../build_cd.conf

pushd $CD_BUILD_DIR

apt-ftparchive -c $APTCONF generate $APTCONF_DIR/apt-ftparchive-deb.conf || exit 1
apt-ftparchive -c $APTCONF generate $APTCONF_DIR/apt-ftparchive-udeb.conf || exit 1
apt-ftparchive -c $APTCONF generate $APTCONF_DIR/apt-ftparchive-extras.conf || exit 1
apt-ftparchive -c $APTCONF release $CD_BUILD_DIR/dists/$VERSION > $CD_BUILD_DIR/dists/$VERSION/Release || exit 1

gpg --default-key $YOURKEYID --output $CD_BUILD_DIR/dists/$VERSION/Release.gpg -ba $CD_BUILD_DIR/dists/$VERSION/Release || exit 1

mkdir -p dists/$VERSION/extras/binary-$ARCH pool/extras/ isolinux preseed

RELEASE_FILE=dists/$VERSION/extras/binary-$ARCH/Release

echo "Archive: $VERSION" > $RELEASE_FILE
echo "Version: $VERSION_NUMBER" >> $RELEASE_FILE
echo Component: extras >> $RELEASE_FILE
echo Origin: Ubuntu >> $RELEASE_FILE
echo Label: Ubuntu >> $RELEASE_FILE
echo Architecture: $ARCH >> $RELEASE_FILE

rm -rf pool/extras/*
cp -r $EXTRAS_DIR/* pool/extras

popd
