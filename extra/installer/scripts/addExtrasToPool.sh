#!/bin/bash

. ../build_cd.conf



pushd $CD_BUILD_DIR

mkdir -p dists/$VERSION/extras/binary-i386 pool/extras/ isolinux preseed

RELEASE_FILE=dists/$VERSION/extras/binary-i386/Release


echo "Archive: $VERSION" > $RELEASE_FILE
echo "Version: $VERSION_NUMBER" >> $RELEASE_FILE
echo Component: extras >> $RELEASE_FILE
echo Origin: Ubuntu >> $RELEASE_FILE
echo Label: Ubuntu >> $RELEASE_FILE
echo Architecture: i386 >> $RELEASE_FILE


rm -rf pool/extras/*
cp -r $EXTRAS_DIR/* pool/extras  || exit 1


popd
