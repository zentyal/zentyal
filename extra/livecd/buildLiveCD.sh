#!/bin/bash

FILES_DIR="./files"

PACKAGES_TO_INSTALL="xserver-xorg x-window-system-core xbase-clients firefox-2 icewm"
REMASTERSYS_PACKAGES="remastersys"

echo '' >> /etc/apt/sources.list
echo 'deb http://www.remastersys.klikit-linux.com/repository remastersys/' >> /etc/apt/sources.list
apt-get update || exit 1
apt-get install -y $REMASTERSYS_PACKAGES || exit 1



test -d $FILES_DIR || (echo "Incorrect files directory $FILES_DIR" && exit 1)

apt-get install -y $PACKAGES_TO_INSTALL || exit 1


cp -v $FILES_DIR/remastersys.conf /etc/remastersys.conf || exit 1

cp -v $FILES_DIR/99x11-common_start /etc/X11/Xsession.d || exit 1

cp -v $FILES_DIR/eboxlive /etc/init.d/ || exit 1
chmod a+rx  /etc/init.d/eboxlive       || exit 1
update-rc.d eboxlive start 99 2 .      || exit 1


echo Copyng firefox default profile..
cp -r $FILES_DIR/firefox_profile/* /etc/firefox/profile || exit 1



echo Running "remastersys dist"
remastersys dist

