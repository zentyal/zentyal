#!/bin/bash

test -r build_cd.conf || exit 1
. ./build_cd.conf

if [ -f $BASE_DIR/DEBUG_MODE ]
then
    $BASE_DIR/set-debug.sh
fi

SELECTED_ARCH=$1

TMPDIR=/tmp/zentyal-installer-build-$$
mkdir $TMPDIR

# Download ubuntu keyring if not exists
test -f $UBUNTU_KEYRING_TAR || wget $UBUNTU_KEYRING_URL

# Build zenbuntu-core package including zentyal-core deps
cp -rL zenbuntu-core $TMPDIR/zenbuntu-core
CORE_DEPS=`./extract-core-deps.sh`
sed -i "s/^Depends: /Depends: $CORE_DEPS /" $TMPDIR/zenbuntu-core/debian/control
pushd $TMPDIR/zenbuntu-core
dpkg-buildpackage
popd

cp -rL zenbuntu-desktop $TMPDIR/zenbuntu-desktop
pushd $TMPDIR/zenbuntu-desktop
dpkg-buildpackage
popd

# Build zinstaller-headless udeb
cp -rL zinstaller-headless $TMPDIR/zinstaller-headless
pushd $TMPDIR/zinstaller-headless
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

    # Add custom extra packages if the dir exists
    for dir in $EXTRAS_CUSTOM_DIR_BASE-$ARCH $EXTRAS_CUSTOM_DIR_BASE-all
    do
        if [ -d $dir ]
        then
            cp $dir/*.deb $EXTRAS_DIR/
        fi
    done

    # Add zinstaller-headless udeb
    UDEB_DIR=$CD_BUILD_DIR/pool/main/z/zinstaller-headless
    mkdir -p $UDEB_DIR
    rm $UDEB_DIR/*
    cp $TMPDIR/zinstaller-headless*.udeb $UDEB_DIR/

    test -d $CD_BUILD_DIR/isolinux || (echo "isolinux directory not found in $CD_BUILD_DIR."; false) || exit 1
    test -d $CD_BUILD_DIR/.disk || (echo ".disk directory not found in $CD_BUILD_DIR."; false) || exit 1

    cp images/splash.* $CD_BUILD_DIR/isolinux/
    cp images/splash.png $CD_BUILD_DIR/install/netboot/ubuntu-installer/$ARCH/boot-screens/
    pushd $CD_BUILD_DIR/isolinux
    mkdir tmp
    cd tmp
    cat ../bootlogo | cpio -i
    cp $BASE_DIR/images/splash.pcx .
    find . | cpio -o > ../bootlogo
    cd ..
    rm -rf tmp
    popd

    pushd $SCRIPTS_DIR

    for SCRIPT in [0-9][0-9]_*.sh; do
        ./$SCRIPT $ARCH || (echo "$SCRIPT failed"; false) || exit 1
    done

    popd

    echo "Installer image for $ARCH created in $ISO_IMAGE."
done

rm -rf $TMPDIR

exit 0
