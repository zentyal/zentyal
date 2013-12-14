#!/bin/bash

. ../build_cd.conf

ARCH=$1

CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"
CD_ZENTYAL_DIR=$CD_BUILD_DIR/zentyal

test -d $CD_BUILD_DIR || (echo "cd build directory not found."; false) || exit 1
test -d $DATA_DIR  || (echo "data directory not found."; false) || exit 1

cp $DATA_DIR/zentyal.seed $CD_BUILD_DIR/preseed/ubuntu-server.seed

cp $CD_BUILD_DIR/preseed/ubuntu-server.seed $CD_BUILD_DIR/preseed/ubuntu-server-auto.seed
cat $DATA_DIR/zentyal-auto.seed >> $CD_BUILD_DIR/preseed/ubuntu-server-auto.seed

cp $CD_BUILD_DIR/preseed/ubuntu-server.seed $CD_BUILD_DIR/preseed/disaster-recovery.seed
sed -i 's/INSTALL_MODE/RECOVER_MODE/g' $CD_BUILD_DIR/preseed/disaster-recovery.seed
cp $CD_BUILD_DIR/preseed/disaster-recovery.seed $CD_BUILD_DIR/preseed/disaster-recovery-auto.seed
cat $DATA_DIR/zentyal-auto.seed >> $CD_BUILD_DIR/preseed/disaster-recovery-auto.seed

UDEB_INCLUDE=$CD_BUILD_DIR/.disk/udeb_include

if [ "$INCLUDE_REMOTE" == "true" ]
then
    if ! grep -q zinstaller-remote $UDEB_INCLUDE
    then
        echo zinstaller-remote >> $UDEB_INCLUDE
    fi
fi

if ! grep -q zinstaller-headless $UDEB_INCLUDE
then
    echo zinstaller-headless >> $UDEB_INCLUDE
fi

# Add https apt method to be able to retrieve from QA updates repo
echo apt-transport-https > $CD_BUILD_DIR/.disk/base_include

if [ -f $BASE_DIR/DEBUG_MODE ]
then
    cp $CD_BUILD_DIR/preseed/ubuntu-server-auto.seed $CD_BUILD_DIR/preseed/ubuntu-server-debug.seed
    cat $DATA_DIR/zentyal-debug.seed >> $CD_BUILD_DIR/preseed/ubuntu-server-debug.seed

    cp $CD_BUILD_DIR/preseed/ubuntu-server-debug.seed $CD_BUILD_DIR/preseed/disaster-recovery-debug.seed
    sed -i 's/INSTALL_MODE/RECOVER_MODE/g' $CD_BUILD_DIR/preseed/disaster-recovery-debug.seed

    cp $DATA_DIR/isolinux-zentyal-debug.cfg $CD_BUILD_DIR/isolinux/txt.cfg
else
    sed -e s:VERSION:$VERSION: < $DATA_DIR/isolinux-zentyal.cfg.template > $CD_BUILD_DIR/isolinux/txt.cfg
fi

USB_SUPPORT="cdrom-detect\/try-usb=true"
sed -i "s/gz quiet/gz $USB_SUPPORT quiet/g" $CD_BUILD_DIR/isolinux/txt.cfg

test -d $CD_ZENTYAL_DIR || mkdir -p $CD_ZENTYAL_DIR

rm -rf $CD_ZENTYAL_DIR/*

TMPDIR=/tmp/zentyal-installer-data-$$
cp -r $DATA_DIR $TMPDIR

./gen_locales.pl $TMPDIR || (echo "locales files autogeneration failed.";
                             echo "make sure you have zentyal-common installed."; false) || exit 1

cp -r $TMPDIR/* $CD_ZENTYAL_DIR/

rm -rf $TMPDIR
