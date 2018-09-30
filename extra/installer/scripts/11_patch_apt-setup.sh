#!/bin/bash

. ../build_cd.conf

ARCH=$1

CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"

pushd $BASE_DIR

apt-get source apt-setup
wget https://launchpadlibrarian.net/363997187/replace_apt_key_add.patch

pushd apt-setup-*

rm -f ../apt-setup*deb
patch -p1 < ../replace_apt_key_add.patch
dpkg-buildpackage -rfakeroot -m"'$ZINSTALLER_ADDRESS'" -k$ZINSTALLER_KEYID
cp -v ../apt-setup*deb $CD_BUILD_DIR/pool/main/a/apt-setup

sudo unsquashfs $CD_BUILD_DIR/install/filesystem.squashfs
sudo cp ../apt-setup*.deb squashfs-root/
sudo chroot squashfs-root sh -c "dpkg -i apt-setup*.deb"
sudo rm squashfs-root/apt-setup*.deb

sudo mksquashfs squashfs-root filesystem.squashfs
mv -f filesystem.squashfs $CD_BUILD_DIR/install/
printf $(sudo du -sx --block-size=1 squashfs-root | cut -f1) > $CD_BUILD_DIR/install/filesystem.size
sudo rm -rf squashfs-root

popd
