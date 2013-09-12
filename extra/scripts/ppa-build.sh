#!/bin/bash

# Array of keys allowed to sign
SIGN_KEYS=()
SIGN_KEYS+=('77E038F7D8E88AAB') # kernevil
SIGN_KEYS+=('19AD31B8')         # TODO jacalvo update this to long key id

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

if [ -z "$KEY_ID" ]; then
    echo "Key not found!"
    exit 1
fi

dpkg-buildpackage -k$KEY_ID -S -sa
