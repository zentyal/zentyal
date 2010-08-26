#!/bin/bash

. ../build_cd.conf

test -d $CD_BUILD_DIR || (echo "cd build directory not found."; false) || exit 1
test -d $DATA_DIR  || (echo "data directory not found."; false) || exit 1

cp $DATA_DIR/ubuntu-ebox.seed $CD_BUILD_DIR/preseed/ubuntu-server.seed
cp $DATA_DIR/ubuntu-ebox-auto.seed $CD_BUILD_DIR/preseed/ubuntu-server-auto.seed
sed -e s:VERSION:$EBOX_VERSION$EBOX_APPEND: < $DATA_DIR/isolinux-ebox.cfg.template > $CD_BUILD_DIR/isolinux/isolinux.cfg

test -d $CD_EBOX_DIR || mkdir -p $CD_EBOX_DIR

rm -rf $CD_EBOX_DIR/*

TMPDIR=/tmp/zentyal-installer-data-$$
svn export $DATA_DIR $TMPDIR
cp -r $TMPDIR/* $CD_EBOX_DIR/
rm -rf $TMPDIR
