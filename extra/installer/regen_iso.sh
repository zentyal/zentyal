#!/bin/bash

test -r build_cd.conf || exit 1
. ./build_cd.conf

SELECTED_ARCH=$1

for ARCH in $ARCHS
do
    if [ -n "$SELECTED_ARCH" ] && [ "$ARCH" != "$SELECTED_ARCH" ]
    then
        continue
    fi

    pushd $SCRIPTS_DIR

    ./40_update_md5sum.sh $ARCH || exit 1
    ./50_mkisofs.sh $ARCH || exit 1

    popd

    echo "Installer image for $ARCH created in $ISO_IMAGE."
done

exit 0

