#!/bin/bash

. ../build_cd.conf

ARCH=$1

ISO_IMAGE="$ISO_IMAGE_BASE-$ARCH.iso"
CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"

mkisofs -r -V "Zentyal $VERSION $ARCH" \
            -cache-inodes \
            -J -l -b isolinux/isolinux.bin \
            -c isolinux/boot.cat -no-emul-boot \
            -boot-load-size 4 -boot-info-table \
            -o $ISO_IMAGE $CD_BUILD_DIR

pushd $BASE_DIR
md5sum $(basename $ISO_IMAGE) > $ISO_IMAGE.md5
popd
