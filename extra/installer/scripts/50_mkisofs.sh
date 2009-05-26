#!/bin/bash

. ../build_cd.conf

mkisofs -r -V "eBox Platform $EBOX_VERSION$EBOX_APPEND $ARCH" \
            -cache-inodes \
            -J -l -b isolinux/isolinux.bin \
            -c isolinux/boot.cat -no-emul-boot \
            -boot-load-size 4 -boot-info-table \
            -o $ISO_IMAGE $CD_BUILD_DIR

md5sum $ISO_IMAGE > $ISO_IMAGE.md5
