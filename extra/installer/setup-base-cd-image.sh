#!/bin/bash

test -r build_cd.conf || exit 1
. ./build_cd.conf

ARCH=$1

if [ "$ARCH" != "i386" -a "$ARCH" != "amd64" ]
then
    echo "Usage: $0 [i386|amd64]"
    exit 1
fi

ISO_PATH="$ISO_PATH_BASE-$ARCH.iso"
CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"
CD_MOUNT_DIR="$CD_MOUNT_DIR_BASE-$ARCH"

test -d $BASE_DIR || (echo "BASE_DIR directory not found."; false) || exit 1

if ! [ -r $ISO_PATH ]
then
    zenity 2>/dev/null
    if [ $? == 255 ]
    then
        ISO_NAME=`basename $ISO_PATH`
        SELECTED_ISO=`zenity --file-selection --title "Locate your $ISO_NAME"`
        if [ -n "$SELECTED_ISO" ]
        then
            ln -s "$SELECTED_ISO" $ISO_PATH
        fi
    fi
fi
test -r $ISO_PATH || (echo "ISO image $ISO_PATH not found."; false) || exit 1

test -r $UBUNTU_KEYRING_TAR || wget $UBUNTU_KEYRING_URL

mkdir -p $CD_MOUNT_DIR || exit 1
sudo mount -o loop $ISO_PATH $CD_MOUNT_DIR || exit 1

rm -rf $CD_BUILD_DIR || exit 1
cp -r $CD_MOUNT_DIR $CD_BUILD_DIR || exit 1
chmod u+w -R $CD_BUILD_DIR || exit 1

sudo umount $CD_MOUNT_DIR || exit 1
rmdir $CD_MOUNT_DIR

echo "Installer build directory generated from contents of $ISO_PATH"

exit 0
