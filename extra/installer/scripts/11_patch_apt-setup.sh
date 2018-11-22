#!/bin/bash

. ../build_cd.conf

ARCH=$1

CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"

pushd $BASE_DIR

sudo sh -c 'echo "deb-src http://archive.ubuntu.com/ubuntu/ bionic main restricted" > /etc/apt/sources.list.d/apt-setup-bionic.list'
sudo apt-get update
apt-get source apt-setup
sudo rm -rf /etc/apt/sources.list.d/apt-setup-bionic.list

wget https://launchpadlibrarian.net/363997187/replace_apt_key_add.patch

pushd apt-setup-*

patch -p1 < ../replace_apt_key_add.patch
dpkg-buildpackage -rfakeroot -m"'$ZINSTALLER_ADDRESS'" -k$ZINSTALLER_KEYID
cp -v ../apt*setup*deb $CD_BUILD_DIR/pool/main/a/apt-setup

popd

popd
