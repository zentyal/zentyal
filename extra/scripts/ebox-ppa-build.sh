#!/bin/bash

# Builds all the packages modified in the working copy.
# Also copies the new debian/changelog to packaging

# If a list of packages is passed by argument it
# builds them instead of the modified.

BRANCH="hardy/trunk"

# Change this with your PPA key ID
KEY_ID="19AD31B8"

if [ $# -gt 0 ]
then
    packages="$@"
else
    packages=`svn status|grep configure.ac|cut -d'/' -f2|sort|uniq`
fi

cwd=`pwd`
for i in $packages
do
    changelog="../packaging/debian/$BRANCH/$i/changelog"
    svn revert $changelog
    echo "Building package $i..."
    ebox-package $i || exit 1
    cd debs-ppa
    dpkg-source -x *${i}_*.dsc || exit 1
    cd *${i}-*
    dpkg-buildpackage -k$KEY_ID -S -sa || exit 1
    cp debian/changelog "../../$changelog"
    cd $cwd
done
