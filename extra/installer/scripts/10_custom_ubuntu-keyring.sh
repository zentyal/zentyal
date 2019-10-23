#!/bin/bash

. ../build_cd.conf

ARCH=$1

CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"

pushd $BASE_DIR

rm -rf $UBUNTU_KEYRING_DIR
tar xzf $UBUNTU_KEYRING_TAR

popd

pushd $UBUNTU_KEYRING_DIR/keyrings

gpg --import < ubuntu-keyring-2012-cdimage.gpg
# Ubuntu CD Image Automatic Signing Key (2012) <cdimage@ubuntu.com> 843938DF228D22F7B3742BC0D94AA3F0EFE21092
gpg --export 843938DF228D22F7B3742BC0D94AA3F0EFE21092 $ZINSTALLER_KEYID > ubuntu-keyring-2012-cdimage.gpg

popd

pushd $UBUNTU_KEYRING_DIR

rm -f ../ubuntu-keyring*deb
sed -i 's/binary: checkkeyrings/binary:/' debian/rules
dpkg-buildpackage -rfakeroot -m"'$ZINSTALLER_ADDRESS'" -k$ZINSTALLER_KEYID
cp -v ../ubuntu-keyring*deb $CD_BUILD_DIR/pool/main/u/ubuntu-keyring

sudo unsquashfs $CD_BUILD_DIR/install/filesystem.squashfs
sudo cp ../ubuntu-keyring*.deb squashfs-root/
sudo cp ../zenbuntu-core/zentyal-6.1-packages.asc squashfs-root/etc/apt/trusted.gpg.d/
sudo chroot squashfs-root sh -c "dpkg -i ubuntu-keyring*.deb"
sudo rm squashfs-root/ubuntu-keyring*.deb

sudo mksquashfs squashfs-root filesystem.squashfs
mv -f filesystem.squashfs $CD_BUILD_DIR/install/
printf $(sudo du -sx --block-size=1 squashfs-root | cut -f1) > $CD_BUILD_DIR/install/filesystem.size
sudo rm -rf squashfs-root

popd
