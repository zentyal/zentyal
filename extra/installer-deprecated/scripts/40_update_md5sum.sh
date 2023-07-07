#!/bin/bash

. ../build_cd.conf

ARCH=$1

CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"

pushd $CD_BUILD_DIR

rm -f md5sum.txt
find . -type f -print0 | xargs -0 md5sum > md5sum.txt
sed -i '/md5sum.txt/d' md5sum.txt
sed -i '/boot.cat/d' md5sum.txt
sed -i '/isolinux.bin/d' md5sum.txt

popd
