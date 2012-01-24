#!/bin/bash

. ../build_cd.conf

ARCH=$1

CD_BUILD_DIR="$CD_BUILD_DIR_BASE-$ARCH"

# Rebrand newt palette
pushd $CD_BUILD_DIR/install
mkdir tmp
cd tmp
gunzip < ../initrd.gz | cpio --extract --preserve
cp $DATA_DIR/palette.zentyal etc/newt/palette.ubuntu
find . | cpio --create --'format=newc' | gzip > ../initrd.gz
cd ..
rm -rf tmp
popd

# Change default hostname
pushd $CD_BUILD_DIR/pool/main/n/netcfg/
NET_UDEB=`ls netcfg_*.udeb`
mkdir tmp
cd tmp
dpkg-deb -e ../$NET_UDEB
dpkg-deb -x ../$NET_UDEB .
sed -i "s/ubuntu/zentyal/g" DEBIAN/templates
dpkg-deb -b . ../$NET_UDEB
cd ..
rm -rf tmp
popd

# Disable tasksel
pushd $CD_BUILD_DIR/pool/main/p/pkgsel/
PKG_UDEB=`ls pkgsel_*.udeb`
mkdir tmp
cd tmp
dpkg-deb -e ../$PKG_UDEB
dpkg-deb -x ../$PKG_UDEB .
sed -i "s/.*install tasksel.*/true/g" DEBIAN/postinst
sed -i "s/.*tasksel --new-install.*/true/g" DEBIAN/postinst
dpkg-deb -b . ../$PKG_UDEB
cd ..
rm -rf tmp
popd
