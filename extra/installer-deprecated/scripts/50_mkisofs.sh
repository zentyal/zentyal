#!/bin/bash

. ../build_cd.conf

ARCH=$1

ISO_IMAGE="$ISO_IMAGE_BASE-$ARCH.iso"
CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"

xorriso -as mkisofs -r -V "Zentyal $VERSION $ARCH" \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -iso-level 4 -b isolinux/isolinux.bin \
            -c isolinux/boot.cat \
            -eltorito-alt-boot \
            -e boot/grub/efi.img -no-emul-boot \
            -o $ISO_IMAGE $CD_BUILD_DIR

pushd $BASE_DIR
isohybrid -u $ISO_IMAGE
md5sum $(basename $ISO_IMAGE) > $ISO_IMAGE.md5
popd
