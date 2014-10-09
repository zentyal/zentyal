#!/bin/bash

# Array of keys allowed to sign
SIGN_KEYS=()
SIGN_KEYS+=('77E038F7D8E88AAB') # kernevil
SIGN_KEYS+=('F9FEF52C19AD31B8') # jacalvo
SIGN_KEYS+=('38FD168F6F20BA36') # jenkins

# Get the list of available keys
SYSTEM_KEYS=($(gpg --list-public-keys --with-colons | awk -F ':' '{print $5}'))

for ((i=0;i < ${#SIGN_KEYS[@]};i++)) {
    K=${SIGN_KEYS[$i]}
    for ((j=0; j < ${#SYSTEM_KEYS[@]}; j++)) {
        S=${SYSTEM_KEYS[$j]}
        if [ "$K" == "$S" ]; then
            KEY_ID=$S
        fi
    }
}

ADD_CHANGELO_ENTRY=$1
if [ -n "$ADD_CHANGELO_ENTRY" ]
then
    version=`sed -n "/^[0-9]/p" ChangeLog|head -1`
    dch -b -v "$version" -D 'trusty' --force-distribution 'New upstream release'
fi

if [ -z "$KEY_ID" ]; then
    echo "Key not found!"
    exit 1
fi

BUILD_DEB=$1
if [ -n "$BUILD_DEB" ]
then
    build_if_changelog_modified=`git ls-files -m|grep ChangeLog`
    if [ -n "$build_if_changelog_modified" ]
    then
        dpkg-buildpackage -k$KEY_ID -sa
    else
        echo "Not building the package because the Changelog it's not modified"
    fi
else
    dpkg-buildpackage -k$KEY_ID -S -sa
fi
