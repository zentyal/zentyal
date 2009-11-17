#!/bin/bash

. ../build_cd.conf

(test -d $INDICES_DIR) || mkdir -p $INDICES_DIR

pushd $INDICES_DIR

echo "Downloading indices files"
wget -m http://archive.ubuntu.com/ubuntu/indices/override.$VERSION.{extra.main,main,main.debian-installer,restricted,restricted.debian-installer} || exit 1

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

apt-ftparchive -c $APTCONF generate $APTCONF_DIR/apt-ftparchive-deb.conf || exit 1
apt-ftparchive -c $APTCONF generate $APTCONF_DIR/apt-ftparchive-udeb.conf || exit 1
apt-ftparchive -c $APTCONF generate $APTCONF_DIR/apt-ftparchive-extras.conf || exit 1
apt-ftparchive -c $APTCONF release $CD_BUILD_DIR/dists/$VERSION > $CD_BUILD_DIR/dists/$VERSION/Release || exit 1

rm -f $CD_BUILD_DIR/dists/$VERSION/Release.gpg
gpg --default-key $YOURKEYID --output $CD_BUILD_DIR/dists/$VERSION/Release.gpg -ba $CD_BUILD_DIR/dists/$VERSION/Release || exit 1

popd
