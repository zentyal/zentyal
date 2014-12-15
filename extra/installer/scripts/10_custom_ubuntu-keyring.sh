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
# Ubuntu CD Image Automatic Signing Key (2012) <cdimage@ubuntu.com>
# Ubuntu Archive Automatic Signing Key (2012) <ftpmaster@ubuntu.com>
gpg --export FBB75451 437D05B5 C0B21F32 EFE21092 $ZINSTALLER_KEYID > ubuntu-archive-keyring.gpg

popd

pushd $UBUNTU_KEYRING_DIR

rm -f ../ubuntu-keyring*deb
dpkg-buildpackage -rfakeroot -m"'$ZINSTALLER_ADDRESS'" -k$ZINSTALLER_KEYID
cp -v ../ubuntu-keyring*deb $CD_BUILD_DIR/pool/main/u/ubuntu-keyring

sudo unsquashfs $CD_BUILD_DIR/install/filesystem.squashfs
sudo cp ../ubuntu-keyring*.deb squashfs-root/
sudo chroot squashfs-root sh -c "dpkg -i ubuntu-keyring*.deb"
sudo rm squashfs-root/ubuntu-keyring*.deb

# Add https apt method to be able to retrieve from QA updates repo
sudo cp /etc/resolv.conf squashfs-root/etc/resolv.conf
sudo chroot squashfs-root sh -c "apt-get install -y --force-yes --no-install-recommends apt-transport-https"
#mkdir -p squashfs-root/usr/lib/apt/methods
#sudo cp /usr/lib/apt/methods/https squashfs-root/usr/lib/apt/methods/

sudo mksquashfs squashfs-root filesystem.squashfs
mv -f filesystem.squashfs $CD_BUILD_DIR/install/
printf $(sudo du -sx --block-size=1 squashfs-root | cut -f1) > $CD_BUILD_DIR/install/filesystem.size
sudo rm -rf squashfs-root

popd
