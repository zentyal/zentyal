#!/bin/bash

sudo true

sed -i "s:^db_get netcfg/get_hostname:RET=$HOSTNAME:" debian/postinst
sed -i "/udeb/d" debian/control
sed -i "/XB-Installer/d" debian/control

dpkg-buildpackage

echo PURGE | sudo debconf-communicate zinstaller-remote

sudo dpkg -i ../zinstaller-remote*deb
