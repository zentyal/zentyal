#!/bin/bash

. ../build_cd.conf

pushd $CD_BUILD_DIR

rm -f md5sum.txt
find . -type f -print0 | xargs -0 md5sum > md5sum.txt 

popd
