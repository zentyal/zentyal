#!/bin/bash

. ../build_cd.conf

ARCH=$1

CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"

pushd $BASE_DIR

rm -rf $UBUNTU_KEYRING_DIR
tar xzf $UBUNTU_KEYRING_TAR

popd

pushd $UBUNTU_KEYRING_DIR/keyrings

gpg --import < ubuntu-archive-keyring.gpg
# Ubuntu CD Image Automatic Signing Key <cdimage@ubuntu.com>
# Ubuntu Archive Automatic Signing Key <ftpmaster@ubuntu.com>
gpg --export FBB75451 437D05B5 $ZINSTALLER_KEYID > ubuntu-archive-keyring.gpg

popd

pushd $UBUNTU_KEYRING_DIR

rm -f ../ubuntu-keyring*deb
dpkg-buildpackage -rfakeroot -m"'$ZINSTALLER_ADDRESS'" -k$ZINSTALLER_KEYID
cp -v ../ubuntu-keyring*deb $CD_BUILD_DIR/pool/main/u/ubuntu-keyring

popd
