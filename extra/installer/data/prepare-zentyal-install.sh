#!/bin/bash

export LOG=/tmp/zentyal-installer.log
SOURCES_LIST=/etc/apt/sources.list
PPA_URL="http://ppa.launchpad.net/zentyal/2.3/ubuntu"
EBOX_SOURCES="deb $PPA_URL precise main"
ARCHIVE_URL="http://archive.zentyal.org/zentyal"
ARCHIVE_SOURCES="deb $ARCHIVE_URL 2.3 main"
EXTRA_URL="http://archive.zentyal.com/zentyal"
EXTRA_SOURCES="deb $EXTRA_URL 2.3 extra"
PKG_DIR=/var/tmp/zentyal-packages
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


# copy *.deb files from CD to hard disk
PKG_DIR=/var/tmp/zentyal-packages
mkdir $PKG_DIR
files=`find /media/cdrom/pool -name '*.deb'`
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

#if ! grep -q ${ARCHIVE_URL} ${SOURCES_LIST}
#then
#    echo ${ARCHIVE_SOURCES} >> ${SOURCES_LIST} # add zentyal archive sources
#fi

#if ! grep -q ${EXTRA_URL} ${SOURCES_LIST}
#then
#    echo ${EXTRA_SOURCES} >> ${SOURCES_LIST} # add zentyal extra sources
#fi

update_if_network # apt-get update if we are connected to the internet

gen_locales

if [ -f /tmp/RECOVER_MODE ]
then
    # Set DR flag for second stage
    DISASTER_FILE=/var/tmp/.zentyal-disaster-recovery
    touch $DISASTER_FILE
    chown :admin $DISASTER_FILE
    chown g+w $DISASTER_FILE

    # Clean DR flag for first stage
    echo "zentyal-core zentyal-core/dr_install boolean false" | debconf-set-selections
fi

if -f /etc/default/grub
then
    if ! grep -q splash /etc/default/grub
    then
        sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 splash"/' /etc/default/grub
    fi
fi

### CUSTOM_ACTION ###

sync

exit 0
