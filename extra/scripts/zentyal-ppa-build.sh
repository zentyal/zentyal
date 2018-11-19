#!/bin/bash

# Builds all the packages modified in the working copy.
# Also copies the new debian/changelog to packaging

# If a list of packages is passed by argument it
# builds them instead of the modified.

# Array of keys allowed to sign
SIGN_KEYS=()
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

if [ -z "$KEY_ID" ]; then
    echo "Key not found!"
    exit 1
fi

if [ $# -gt 0 ]
then
    packages="$@"
else
    packages=`git ls-files -m|grep ChangeLog|cut -d' ' -f8|cut -d'/' -f1|sort|uniq`
fi

cwd=`pwd`
for i in $packages
do
    changelog="$i/debian/changelog"
    git checkout $changelog
    echo "Building package $i..."
    ../extra/zbuildtools/zentyal-package $i || exit 1
    cd debs-ppa
    dpkg-source -x zentyal-${i}_*.dsc || exit 1
    cd zentyal-${i}-*
    dpkg-buildpackage -S -us -uc || exit 1
    cp debian/changelog "../../$changelog"
    cd $cwd
done

# Show notification if libnotify-bin is installed
which notify-send || exit 0
name=`basename $0`
notify-send $name "The build of the following packages has finished: $@"
