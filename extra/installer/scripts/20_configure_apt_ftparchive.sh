#!/bin/bash

. ../build_cd.conf

ARCH=$1

CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"
EXTRAS_DIR="$EXTRAS_DIR_BASE-$ARCH"

(test -d $INDICES_DIR) || mkdir -p $INDICES_DIR

pushd $INDICES_DIR

echo "Downloading indices files"
for i in extra.main main main.debian-installer restricted restricted.debian-installer
do
    wget -N http://archive.ubuntu.com/ubuntu/indices/override.$DIST.$i || exit 1
done

popd

pushd $APTCONF_DIR

echo "Writing apt-ftparchive configuration files"

CONF_FILE_TEMPLATES="apt-ftparchive-deb.conf.template apt-ftparchive-udeb.conf.template apt-ftparchive-extras.conf.template release.conf.template"
for TEMPLATE in $CONF_FILE_TEMPLATES; do
   CONF_FILE=`echo $TEMPLATE | sed  -e s/.template//`
   sed -e s:INDICES:$INDICES_DIR: -e s:ARCHIVE_DIR:$CD_BUILD_DIR: -e s:ARCH:$ARCH: < $TEMPLATE  > $CONF_FILE || exit 1
done

popd

pushd $CD_BUILD_DIR

mkdir -p dists/$DIST/extras/binary-$ARCH pool/extras/ isolinux preseed

RELEASE_FILE=dists/$DIST/extras/binary-$ARCH/Release

echo "Archive: $DIST" > $RELEASE_FILE
echo "Version: $DIST_VERSION" >> $RELEASE_FILE
echo Component: extras >> $RELEASE_FILE
echo Origin: Ubuntu >> $RELEASE_FILE
echo Label: Ubuntu >> $RELEASE_FILE
echo Architecture: $ARCH >> $RELEASE_FILE

rm -rf pool/extras/*
cp $EXTRAS_DIR/*.deb pool/extras/

apt-ftparchive -c $APTCONF generate $APTCONF_DIR/apt-ftparchive-deb.conf || exit 1
apt-ftparchive -c $APTCONF generate $APTCONF_DIR/apt-ftparchive-udeb.conf || exit 1
apt-ftparchive -c $APTCONF generate $APTCONF_DIR/apt-ftparchive-extras.conf || exit 1
apt-ftparchive -c $APTCONF release $CD_BUILD_DIR/dists/$DIST > $CD_BUILD_DIR/dists/$DIST/Release || exit 1

rm -f $CD_BUILD_DIR/dists/$DIST/Release.gpg
gpg --default-key $ZINSTALLER_KEYID --output $CD_BUILD_DIR/dists/$DIST/Release.gpg -ba $CD_BUILD_DIR/dists/$DIST/Release || exit 1

popd
