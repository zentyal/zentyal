#!/bin/bash -x

test -r build_cd.conf || exit 1
. ./build_cd.conf

test -d $CD_BUILD_DIR || (echo "cd build directory not found."; false) || exit 1
test -d $EXTRAS_DIR   || (echo "extra packages directory not found."; false) || exit 1

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
    ./$SCRIPT || (echo "$SCRIPT failed"; false) || exit 1
done

popd

echo "installer image created in $ISO_IMAGE."

exit 0
