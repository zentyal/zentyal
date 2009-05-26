#!/bin/bash -x

test -r build_cd.conf || exit 1
. ./build_cd.conf

sudo rm -fr $CHROOT
mkdir $CHROOT

sudo debootstrap --arch=$ARCH $VERSION $CHROOT

echo "deb http://archive.ubuntu.com/ubuntu hardy main restricted universe multiverse" > sources.list
echo "deb http://archive.ubuntu.com/ubuntu hardy-updates main restricted universe multiverse" >> sources.list
echo "deb http://security.ubuntu.com/ubuntu hardy-security main restricted universe" >> sources.list
echo "deb http://ppa.launchpad.net/ebox-unstable/ppa/ubuntu hardy main" >> sources.list
sudo mv sources.list $CHROOT/etc/apt/sources.list

sudo chroot $CHROOT apt-get update

sudo chroot $CHROOT apt-get install --download-only --allow-unauthenticated --yes ebox-*

cp $CHROOT/var/cache/apt/archives/*.deb $EXTRAS_DIR/
