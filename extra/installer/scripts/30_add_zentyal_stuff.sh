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

cp $DATA_DIR/zentyal.seed $CD_BUILD_DIR/preseed/upgrade.seed
if [ -f $DATA_DIR/zentyal-upgrade.seed ]
then
    cat $DATA_DIR/zentyal-upgrade.seed >> $CD_BUILD_DIR/preseed/upgrade.seed
fi

UDEB_INCLUDE=$CD_BUILD_DIR/.disk/udeb_include

if ! grep -q zinstaller-headless $UDEB_INCLUDE
then
    echo zinstaller-headless >> $UDEB_INCLUDE
fi

ISOLINUXCFG=$CD_BUILD_DIR/isolinux/txt.cfg
if [ -f $BASE_DIR/DEBUG_MODE ]
then
    cp $CD_BUILD_DIR/preseed/ubuntu-server-auto.seed $CD_BUILD_DIR/preseed/ubuntu-server-debug.seed
    cat $DATA_DIR/zentyal-debug.seed >> $CD_BUILD_DIR/preseed/ubuntu-server-debug.seed

    cp $DATA_DIR/isolinux-zentyal-debug.cfg $ISOLINUXCFG
else
    sed -e s:VERSION:$VERSION: < $DATA_DIR/isolinux-zentyal.cfg.template > $ISOLINUXCFG
fi

AUTO_TEXT=$(grep "Install" $ISOLINUXCFG | head -1 | cut -d^ -f2 | sed 's/Install //')
EXPERT_TEXT=$(grep "Install" $ISOLINUXCFG | tail -1 | cut -d^ -f2 | sed 's/Install //')
for i in $CD_BUILD_DIR/isolinux/*.tr
do
    sed -i "s/Edubuntu/$AUTO_TEXT/" $i
    sed -i "s/Kubuntu/$EXPERT_TEXT/" $i
done
sed -i "s/delete all disk/borrar todo el disco/g" $CD_BUILD_DIR/isolinux/es.tr
sed -i "s/expert mode/modo experto/g" $CD_BUILD_DIR/isolinux/es.tr

sed -i 's/timeout 300/timeout 0/' $CD_BUILD_DIR/isolinux/isolinux.cfg

pushd $CD_BUILD_DIR/isolinux
mkdir tmp
cd tmp
cat ../bootlogo | cpio --extract --make-directories --no-absolute-filenames
cp ../*.tr .
find . | cpio -o > ../bootlogo
cd ..
rm -rf tmp
popd

sed -e s:VERSION:$VERSION: < $DATA_DIR/grub.cfg.template > $CD_BUILD_DIR/boot/grub/grub.cfg

USB_SUPPORT="cdrom-detect\/try-usb=true"
sed -i "s/gz quiet/gz $USB_SUPPORT quiet/g" $CD_BUILD_DIR/isolinux/txt.cfg

if echo $VERSION | grep -q daily
then
    DATE=`date +%Y-%m-%d`
    sed -e s:DATE:$DATE: < $DATA_DIR/isolinux-daily.template >> $CD_BUILD_DIR/isolinux/adtxt.cfg
fi

test -d $CD_ZENTYAL_DIR || mkdir -p $CD_ZENTYAL_DIR

rm -rf $CD_ZENTYAL_DIR/*

TMPDIR=/tmp/zentyal-installer-data-$$
cp -r $DATA_DIR $TMPDIR

./gen_locales.pl $TMPDIR || (echo "locales files autogeneration failed.";
                             echo "make sure you have zentyal-common installed."; false) || exit 1

cp -r $TMPDIR/* $CD_ZENTYAL_DIR/

rm -rf $TMPDIR

if [[ $VERSION = *"commercial"* ]]
then
    touch $CD_ZENTYAL_DIR/commercial-edition
fi
