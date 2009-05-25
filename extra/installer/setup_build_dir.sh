#!/bin/bash -x

test -r build_cd.conf || exit 1
. ./build_cd.conf

test -d $BASE_DIR || (echo "base_dir directory not found."; false) || exit 1

test -r $ISO_PATH || (echo "iso image not found."; false) || exit 1

mkdir -p $CD_MOUNT_DIR || exit 1
sudo mount -o loop $ISO_PATH $CD_MOUNT_DIR || exit 1

rm -rf $CD_BUILD_DIR || exit 1
cp -r $CD_MOUNT_DIR $CD_BUILD_DIR || exit 1
chmod o+w -R $CD_BUILD_DIR || exit 1

# remove ppp-udeb
rm $CD_BUILD_DIR/pool/main/p/ppp/ppp-udeb*

# rebranding FIXME
cp images/* $CD_BUILD_DIR/isolinux/
sed -i "s/Ubuntu Server/eBox Platform $EBOX_VERSION/g" $CD_BUILD_DIR/isolinux/isolinux.cfg

sudo umount $CD_MOUNT_DIR || exit 1
rmdir $CD_MOUNT_DIR

echo "installer build directory generated from contents of $ISO"

exit 0
