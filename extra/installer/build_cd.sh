#!/bin/bash

test -r build_cd.conf || exit 1
. ./build_cd.conf

SELECTED_ARCH=$1

for ARCH in $ARCHS
do
    if [ $ARCH != $SELECTED_ARCH ]
    then
        continue
    fi

    CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"
    EXTRAS_DIR="$EXTRAS_DIR_BASE-$ARCH"
    ISO_IMAGE="$ISO_IMAGE_BASE-$ARCH.iso"

    test -d $CD_BUILD_DIR || (echo "CD build directory for $ARCH not found."; false) || exit 1
    test -d $EXTRAS_DIR   || (echo "Extra packages directory for $ARCH not found."; false) || exit 1

    test -d $CD_BUILD_DIR/isolinux || (echo "isolinux directory not found in $CD_BUILD_DIR."; false) || exit 1
    test -d $CD_BUILD_DIR/.disk || (echo ".disk directory not found in $CD_BUILD_DIR."; false) || exit 1

    pushd $SCRIPTS_DIR

    ./gen_locales.pl $DATA_DIR || (echo "locales files autogeneration failed.";
                                   echo "make sure you have libebox installed."; false) || exit 1

    CD_SCRIPTS="\
    10_custom_ubuntu-keyring.sh \
    20_configure_apt_ftparchive.sh \
    30_put_ebox_stuff.sh \
    40_update_md5sum.sh \
    50_mkisofs.sh"
    for SCRIPT in $CD_SCRIPTS; do
        ./$SCRIPT $ARCH || (echo "$SCRIPT failed"; false) || exit 1
    done

    popd

    echo "Installer image for $ARCH created in $ISO_IMAGE."
done

exit 0
