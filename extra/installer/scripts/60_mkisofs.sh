#!/bin/bash

. ../build_cd.conf

mkisofs -r -V "eBox Platform $EBOX_VERSION $ARCH installer" \
            -cache-inodes \
            -J -l -b isolinux/isolinux.bin \
            -c isolinux/boot.cat -no-emul-boot \
            -boot-load-size 4 -boot-info-table \
            -o $ISO_IMAGE $CD_BUILD_DIR
