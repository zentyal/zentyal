#!/bin/bash

# Builds all the packages modified in the working copy.
# Also copies the new debian/changelog to packaging

# If a list of packages is passed by argument it
# builds them instead of the modified.

# Change this with your PPA key ID
KEY_ID="19AD31B8"

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
    git co $changelog
    echo "Building package $i..."
    $cwd/../extra/zbuildtools/zentyal-package $i || exit 1
    cd debs-ppa
    dpkg-source -x zentyal-${i}_*.dsc || exit 1
    cd zentyal-${i}-*
    dpkg-buildpackage -k$KEY_ID -S -sa || exit 1
    cp debian/changelog "../../$changelog"
    cd $cwd
done

# Show notification if libnotify-bin is installed
which notify-send || exit 0
name=`basename $0`
notify-send $name "The build of the following packages has finished: $@"
