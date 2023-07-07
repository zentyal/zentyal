#!/bin/bash

set -e

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

sudo debootstrap --arch=$ARCH --include=gnupg $DIST $CHROOT

sudo cp sources.list $CHROOT/etc/apt/sources.list

cat zenbuntu-core/zentyal-7.0-packages-org.asc | sudo chroot $CHROOT apt-key add -

# install suricata repo GPG key
sudo chroot $CHROOT apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D7F87B2966EB736F

sudo mount none -t devpts /dev/pts
export LC_ALL=C

sudo chroot $CHROOT apt-get update

sudo chroot $CHROOT apt-get purge -y netplan.io

test -r data/extra-packages.list || exit 1
cp data/extra-packages.list /tmp/extra-packages.list
cat /tmp/extra-packages.list | xargs sudo chroot $CHROOT apt-get install --download-only --no-install-recommends --allow-unauthenticated --yes
rm /tmp/extra-packages.list

cp $CHROOT/var/cache/apt/archives/*.deb $EXTRAS_DIR/
