#!/bin/bash

export LOG=/tmp/ebox-installer.log
SOURCES_LIST=/etc/apt/sources.list
PPA_URL="http://ppa.launchpad.net/zentyal/2.0/ubuntu"
EBOX_SOURCES="deb $PPA_URL lucid main"
ZARAFA_SOURCES="deb http://archive.canonical.com/ubuntu lucid partner"
PKG_DIR=/var/tmp/ebox-packages
LOCAL_SOURCES="deb file:$PKG_DIR ./"

create_repository() {
    cd $PKG_DIR
    apt-ftparchive packages . | gzip > Packages.gz 2>>$LOG
    cd - > /dev/null
    # Update the package database with only the local repository
    # just in case we are installing without internet connection
    mv ${SOURCES_LIST} /tmp/ebox
    echo ${LOCAL_SOURCES} > ${SOURCES_LIST}
    apt-get update >> $LOG 2>&1
    # Restore the original sources.list
    mv /tmp/ebox/sources.list ${SOURCES_LIST}
    # Move packages to the cache
    mv $PKG_DIR/*.deb /var/cache/apt/archives/
}

update_if_network() {
    # Import PPA key to avoid warning
    apt-key add /var/tmp/ebox-ppa.asc >> $LOG 2>&1
    # Check if we can connect to the PPA url
    if $(wget -T 10 -t 1 $PPA_URL >> $LOG 2>&1); then
        echo "Updating package database from the network..." >> $LOG
        apt-get update >> $LOG 2>&1
    else
        echo "Warning: Can't connect to $PPA_URL. Updates won't be installed." >> $LOG
    fi
}

gen_locales() {
    # load LANG variable with default locale
    . /etc/default/locale

    # Append Zentyal support languages to generate to current supported
    # locales
    LOCALES_FILE=/var/lib/locales/supported.d/local
    TMP=/tmp/local.tmp
    cat /tmp/ebox/locale.gen $LOCALES_FILE > $TMP
    sort $TMP | uniq > $LOCALES_FILE
    rm -f $TMP

    # Regenerate locales to update the new messages from Zentyal
    /usr/sbin/locale-gen

    /usr/share/ebox/ebox-set-locale $LANG > /dev/null 2>&1
}


# replace motd
cp /tmp/ebox/motd /etc/motd.tail

# copy *.deb files from CD to hard disk
PKG_DIR=/var/tmp/ebox-packages
mkdir $PKG_DIR
#list=`cat /tmp/ebox/extra-packages.list`
#packages=`LANG=C apt-get install $list --simulate|grep ^Inst|cut -d' ' -f2`
#for p in $packages
#do
#    char=$(echo $p | cut -c 1)
#    cp /cdrom/pool/main/{$char,lib$char}/*/${p}_*.deb $PKG_DIR 2> /dev/null
#    cp /cdrom/pool/extras/${p}_*.deb $PKG_DIR 2> /dev/null
#done
files=`find /cdrom/pool -name '*.deb'`
for file in $files
do
    cp $file $PKG_DIR 2> /dev/null
done

create_repository # Set up local package repository

echo ${LOCAL_SOURCES} >> ${SOURCES_LIST} # add local sources
echo ${ZARAFA_SOURCES} >> ${SOURCES_LIST} # add canonical/partner sources

if ! grep -q zentyal ${SOURCES_LIST}
then
    echo ${EBOX_SOURCES} >> ${SOURCES_LIST} # add ppa sources
fi

update_if_network # apt-get update if we are connected to the internet

gen_locales

mv /tmp/ebox /var/tmp
mv /var/tmp/ebox/ebox-x11-setup /etc/rc.local
mv /var/tmp/ebox/plymouth-zentyal /lib/plymouth/themes/zentyal
ln -sf /lib/plymouth/themes/zentyal/zentyal.plymouth /etc/alternatives/default.plymouth

if [ -f /tmp/RECOVER_MODE ]
then
    DISASTER_FILE=/var/tmp/ebox/.disaster-recovery
    touch $DISASTER_FILE
    chown :admin $DISASTER_FILE
    chown g+w $DISASTER_FILE
fi

sed -i 's/start on/start on zentyal-lxdm and/' /etc/init/lxdm.conf

sync

exit 0
