#!/bin/bash

version=$1
rev=$2

if [ -z "$version" ]
then
    echo "Usage: $0 <version> <zentyal revision>"
    exit 1
fi

if [ -z "$rev" ]
then
    echo "Usage: $0 <version> <zentyal revision>"
    exit 1
fi

BUILD_DIR=/tmp/build-samba4-$$
CWD=`pwd`

SAMBA_SRC="samba4_$version.orig.tar.gz"

if ! [ -f $SAMBA_SRC ]
then
    ./build-orig.sh $version
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

mkdir $BUILD_DIR
ln -sf $CWD/$SAMBA_SRC $BUILD_DIR/$SAMBA_SRC

pushd $BUILD_DIR > /dev/null 2>&1
tar xzf $CWD/$SAMBA_SRC
cd samba4_$version
cp -r $CWD/debian .

LAST_CHANGELOG_VERSION="$(dpkg-parsechangelog | awk -F ': ' '$1=="Version" {print $2}')"
NEW_BUILD_VERSION="$version-zentyal$rev"

dpkg --compare-versions $NEW_BUILD_VERSION gt $LAST_CHANGELOG_VERSION
BUILD_VERSION_GREATER=$?
dpkg --compare-versions $NEW_BUILD_VERSION eq $LAST_CHANGELOG_VERSION
BUILD_VERSION_EQUAL=$?


if [ $BUILD_VERSION_EQUAL -eq 0 ]; then
    # If build version is equal to the last changelog entry, ask for
    # confirmation before build but do not update changelog
    read -p "Build version is equeal to last changelog entry. Continue? (y/n): "  CHOICE
    case "$CHOICE" in
      n|N ) exit 0;;
      y|Y ) ;;
      * ) exit 1;;
    esac
elif [ $BUILD_VERSION_GREATER -ne 0 ]; then
    # If build version is lower than last changelog entry, abort
    echo "Build version is older than last version in changelog"
    exit 1
else
    # If build version is newer than last changelog entry, update changelog
    dch -b -v "$version-zentyal$rev" -D 'precise' --force-distribution 'New upstream release'
    cp debian/changelog $CWD/debian/
fi

ppa-build.sh
if [ $? -ne 0 ]; then
    popd > /dev/null 2>&1
    exit 1
fi
popd > /dev/null 2>&1

cp $BUILD_DIR/samba4_$version*.{debian.tar.gz,dsc,changes} .

rm -rf $BUILD_DIR
