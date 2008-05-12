#!/bin/bash -x

. ../build_cd.conf

test -d $CD_BUILD_DIR || (echo "Inexistent CD image dir: $CD_BUILD_DIR" && exit 1)
test -d $DATA_DIR  || (echo "Inexistent source dir: $DATA_DIR" && exit 1)


cp $DATA_DIR/ubuntu-ebox.seed $CD_BUILD_DIR/preseed/ubuntu-server.seed


test -d $CD_EBOX_DIR || mkdir -p $CD_EBOX_DIR

rm -rf $CD_EBOX_DIR/*

cp $DATA_DIR/* $CD_EBOX_DIR/
