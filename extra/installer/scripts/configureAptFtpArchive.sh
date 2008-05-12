#!/bin/bash

. ../build_cd.conf


(test -d $INDICES_DIR) || mkdir -p $INDICES_DIR

pushd $INDICES_DIR

echo "Downloading indices files"
wget http://archive.ubuntu.com/ubuntu/indices/override.$VERSION.{extra.main,main,main.debian-installer,restricted,restricted.debian-installer} || exit 1

popd



pushd $APTCONF_DIR

echo "Writing apt-ftparchive configuration files"

CONF_FILE_TEMPLATES="apt-ftparchive-deb.conf.template apt-ftparchive-udeb.conf.template apt-ftparchive-extras.conf.template"
for TEMPLATE in $CONF_FILE_TEMPLATES; do
   CONF_FILE=`echo $TEMPLATE | sed  -e s/.template//`
   sed -e s:INDICES:$INDICES_DIR: -e s:ARCHIVE_DIR:$CD_BUILD_DIR: < $TEMPLATE  > $CONF_FILE || exit 1
done

popd