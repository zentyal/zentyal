#!/bin/bash

test -r build_cd.conf || exit 1
. ./build_cd.conf

SELECTED_ARCH=$1

TMPDIR=/tmp/zentyal-installer-build-$$
mkdir $TMPDIR

# Download ubuntu keyring if not exists
test -f $UBUNTU_KEYRING_TAR || wget $UBUNTU_KEYRING_URL

# Build zenbuntu-desktop package including core deps
cp -rL zenbuntu-desktop $TMPDIR/zenbuntu-desktop
CORE_DEPS=`./extract-core-deps.sh`
sed -i "s/^Depends: /Depends: $CORE_DEPS /" $TMPDIR/zenbuntu-desktop/debian/control
pushd $TMPDIR/zenbuntu-desktop
dpkg-buildpackage
popd

for ARCH in $ARCHS
do
    if [ -n "$SELECTED_ARCH" ] && [ "$ARCH" != "$SELECTED_ARCH" ]
    then
        continue
    fi

    CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"
    EXTRAS_DIR="$EXTRAS_DIR_BASE-$ARCH"
    ISO_IMAGE="$ISO_IMAGE_BASE-$ARCH.iso"

    test -d $CD_BUILD_DIR || (echo "CD build directory for $ARCH not found."; false) || exit 1
    test -d $EXTRAS_DIR   || (echo "Extra packages directory for $ARCH not found."; false) || exit 1

    # Replace zenbuntu-desktop package
    rm $EXTRAS_DIR/zenbuntu-desktop_*.deb
    cp $TMPDIR/*.deb $EXTRAS_DIR/

    test -d $CD_BUILD_DIR/isolinux || (echo "isolinux directory not found in $CD_BUILD_DIR."; false) || exit 1
    test -d $CD_BUILD_DIR/.disk || (echo ".disk directory not found in $CD_BUILD_DIR."; false) || exit 1

    cp images/* $CD_BUILD_DIR/isolinux/

    pushd $SCRIPTS_DIR

    ./gen_locales.pl $DATA_DIR || (echo "locales files autogeneration failed.";
                                   echo "make sure you have libebox installed."; false) || exit 1

    for SCRIPT in [0-9][0-9]_*.sh; do
        ./$SCRIPT $ARCH || (echo "$SCRIPT failed"; false) || exit 1
    done

    popd

    echo "Installer image for $ARCH created in $ISO_IMAGE."
done

rm -rf $TMPDIR

exit 0
