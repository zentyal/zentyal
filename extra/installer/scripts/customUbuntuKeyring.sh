#!/bin/bash

. ../build_cd.conf

pushd $BASE_DIR

rm -rf $UBUNTU_KEYRING_DIR
tar xzf $UBUNTU_KEYRING_TAR

popd

pushd $UBUNTU_KEYRING_DIR/keyrings

gpg --import < ubuntu-archive-keyring.gpg
gpg --export FBB75451 437D05B5 $YOURKEYID > ubuntu-archive-keyring.gpg

popd


pushd $UBUNTU_KEYRING_DIR

rm -f ../ubuntu-keyring*deb
dpkg-buildpackage -rfakeroot -m"'$MANTAINER_ADDRESS''" -k$YOURKEYID
cp -v ../ubuntu-keyring*deb $CD_BUILD_DIR/pool/main/u/ubuntu-keyring

popd


