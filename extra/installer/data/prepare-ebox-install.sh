#!/bin/bash

export LOG=/tmp/zentyal-installer.log
SOURCES_LIST=/etc/apt/sources.list
PPA_URL="http://ppa.launchpad.net/zentyal/2.2/ubuntu"
EBOX_SOURCES="deb $PPA_URL lucid main"
ARCHIVE_URL="http://archive.zentyal.org/zentyal"
ARCHIVE_SOURCES="deb $ARCHIVE_URL 2.2 main"
EXTRA_URL="http://archive.zentyal.com/zentyal"
EXTRA_SOURCES="deb $EXTRA_URL 2.2 extra"
PKG_DIR=/var/tmp/ebox-packages
LOCAL_SOURCES="deb file:$PKG_DIR ./"

create_repository() {
    cd $PKG_DIR
    apt-ftparchive packages . | gzip > Packages.gz 2>>$LOG
    cd - > /dev/null
    # Update the package database with only the local repository
    # just in case we are installing without internet connection
    mv ${SOURCES_LIST} /tmp/zentyal
    echo ${LOCAL_SOURCES} > ${SOURCES_LIST}
    apt-get update >> $LOG 2>&1
    # Restore the original sources.list
    mv /tmp/zentyal/sources.list ${SOURCES_LIST}
    # Move packages to the cache
    mv $PKG_DIR/*.deb /var/cache/apt/archives/
}

update_if_network() {
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
    cat /tmp/zentyal/locale.gen $LOCALES_FILE > $TMP
    sort $TMP | uniq > $LOCALES_FILE
    rm -f $TMP

    # Install language-pack-$LANG if exists
    suffix=`echo $LANG | cut -d\. -f1 | tr '_' '-' | tr '[A-Z]' '[a-z]'`
    apt-get install -y --force-yes language-pack-zentyal-$suffix
    if [ $? -ne 0 ]
    then
        # Try with xx if xx-yy not exists
        suffix=`echo $suffix | cut -d- -f1`
        apt-get install -y --force-yes language-pack-zentyal-$suffix
    fi

    # Regenerate locales to update the new messages from Zentyal
    /usr/sbin/locale-gen

    /usr/share/zentyal/set-locale $LANG > /dev/null 2>&1
}


# replace motd
cp /tmp/zentyal/motd /etc/motd.tail

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

if ! grep -q ${PPA_URL} ${SOURCES_LIST}
then
    echo ${EBOX_SOURCES} >> ${SOURCES_LIST} # add ppa sources
fi

if ! grep -q ${ARCHIVE_URL} ${SOURCES_LIST}
then
    echo ${ARCHIVE_SOURCES} >> ${SOURCES_LIST} # add zentyal archive sources
fi

if ! grep -q ${EXTRA_URL} ${SOURCES_LIST}
then
    echo ${EXTRA_SOURCES} >> ${SOURCES_LIST} # add zentyal extra sources
fi

# Import keys to avoid warnings
apt-key add /tmp/zentyal/ebox-ppa.asc >> $LOG 2>&1
apt-key add /tmp/zentyal/zentyal-2.2-archive.asc >> $LOG 2>&1
update_if_network # apt-get update if we are connected to the internet

gen_locales

mv /tmp/zentyal /var/tmp
mv /var/tmp/zentyal/ebox-x11-setup /etc/rc.local
mv /var/tmp/zentyal/plymouth-zentyal /lib/plymouth/themes/zentyal
ln -sf /lib/plymouth/themes/zentyal/zentyal.plymouth /etc/alternatives/default.plymouth

if [ -f /tmp/RECOVER_MODE ]
then
    # Set DR flag for second stage
    DISASTER_FILE=/var/tmp/zentyal/.disaster-recovery
    touch $DISASTER_FILE
    chown :admin $DISASTER_FILE
    chown g+w $DISASTER_FILE

    # Clean DR flag for first stage
    echo "zentyal-core zentyal-core/dr_install boolean false" | debconf-set-selections
fi

sed -i 's/start on/start on zentyal-lxdm and/' /etc/init/lxdm.conf

### CUSTOM_ACTION ###

sync

exit 0
