#!/bin/bash

test -r build_cd.conf || exit 1
. ./build_cd.conf

ARCH=$1

if [ "$ARCH" != "i386" -a "$ARCH" != "amd64" ]
then
    echo "Usage: $0 [i386|amd64]"
    exit 1
fi

EXTRAS_DIR="$EXTRAS_DIR_BASE-$ARCH"
CHROOT="$CHROOT_BASE-$ARCH"

test -d $EXTRAS_DIR || mkdir $EXTRAS_DIR

sudo rm -fr $CHROOT
mkdir $CHROOT

sudo debootstrap --arch=$ARCH $VERSION $CHROOT

echo "deb http://archive.ubuntu.com/ubuntu lucid main restricted universe multiverse" > sources.list
echo "deb http://archive.ubuntu.com/ubuntu lucid-updates main restricted universe multiverse" >> sources.list
echo "deb http://security.ubuntu.com/ubuntu lucid-security main restricted universe" >> sources.list
echo "deb http://ppa.launchpad.net/zentyal/2.0/ubuntu lucid main" >> sources.list
echo "deb http://archive.canonical.com/ubuntu lucid partner" >> sources.list
sudo mv sources.list $CHROOT/etc/apt/sources.list

sudo chroot $CHROOT apt-get update

test -r data/extra-packages.list || exit 1
cp data/extra-packages.list /tmp/extra-packages.list
if [ "$ARCH" == "amd64" ]
then
    sed -i '/linux-headers-generic-pae/d' /tmp/extra-packages.list
fi
cat /tmp/extra-packages.list | xargs sudo chroot $CHROOT apt-get install --download-only --no-install-recommends --allow-unauthenticated --yes
rm /tmp/extra-packages.list

cp $CHROOT/var/cache/apt/archives/*.deb $EXTRAS_DIR/

./replace-metapackages.sh $ARCH
