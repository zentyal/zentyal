#!/bin/bash

. ../build_cd.conf

ARCH=$1

CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"
CD_EBOX_DIR=$CD_BUILD_DIR/zentyal

test -d $CD_BUILD_DIR || (echo "cd build directory not found."; false) || exit 1
test -d $DATA_DIR  || (echo "data directory not found."; false) || exit 1

cp $DATA_DIR/ubuntu-ebox.seed $CD_BUILD_DIR/preseed/ubuntu-server.seed
if [ "$ARCH" == "amd64" ]
then
    sed -i 's/linux-generic-pae/linux-server/g' $CD_BUILD_DIR/preseed/ubuntu-server.seed
fi

cp $CD_BUILD_DIR/preseed/ubuntu-server.seed $CD_BUILD_DIR/preseed/ubuntu-server-auto.seed
cat $DATA_DIR/ubuntu-ebox-auto.seed >> $CD_BUILD_DIR/preseed/ubuntu-server-auto.seed

DISASTER_PACKAGES="zentyal-ebackup zentyal-remoteservices zenity"
cp $CD_BUILD_DIR/preseed/ubuntu-server.seed $CD_BUILD_DIR/preseed/disaster-recovery.seed
sed -i 's/INSTALL_MODE/RECOVER_MODE/' $CD_BUILD_DIR/preseed/disaster-recovery.seed
sed -i 's/dr_install boolean false/dr_install boolean true/' $CD_BUILD_DIR/preseed/disaster-recovery.seed
sed -i "s/include string/include string $DISASTER_PACKAGES/" $CD_BUILD_DIR/preseed/disaster-recovery.seed
cp $CD_BUILD_DIR/preseed/disaster-recovery.seed $CD_BUILD_DIR/preseed/disaster-recovery-auto.seed
cat $DATA_DIR/ubuntu-ebox-auto.seed >> $CD_BUILD_DIR/preseed/disaster-recovery-auto.seed

sed -e s:VERSION:$EBOX_VERSION$EBOX_APPEND: < $DATA_DIR/isolinux-ebox.cfg.template > $CD_BUILD_DIR/isolinux/txt.cfg

USB_SUPPORT="cdrom-detect\/try-usb=true"
sed -i "s/gz quiet/gz $USB_SUPPORT quiet/g" $CD_BUILD_DIR/isolinux/txt.cfg

test -d $CD_EBOX_DIR || mkdir -p $CD_EBOX_DIR

rm -rf $CD_EBOX_DIR/*

TMPDIR=/tmp/zentyal-installer-data-$$
cp -r $DATA_DIR $TMPDIR
cp -r $TMPDIR/* $CD_EBOX_DIR/
if [ "$ARCH" == "amd64" ]
then
    sed -i 's/linux-generic-pae/linux-server/g' $CD_EBOX_DIR/extra-packages.list
fi
rm -rf $TMPDIR
