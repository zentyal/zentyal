#!/bin/bash

package=$1
version=$2
rev=$3

###
### Arguments validation
###
if [ -z "$package" ] || [ -z "$version" ]; then
    echo "Usage: $0 [SOPE|SOGo|openchange] <version> [rev]"
    exit 1
fi

if [ "$package" = "openchange" ] && [ "$version" != "latest" ]; then
    echo "We only support 'latest' version for openchange."
    exit 1
fi

if [ -z "$rev" ]
then
    rev=1
fi

###
### Build orig source tarball
###
CWD="$(pwd)"

package_lc=${package,,}
SRC="${package_lc}_$version.orig.tar.gz"

if [ "$version" = "latest" ]; then
    ./build-orig.sh $package $version
    if [ $? -ne 0 ]; then
        exit 1
    fi
    generated=`ls -tr ${package_lc}_*.orig.tar.gz | tail -1`
    version=${generated/${package_lc}_/}
    version=${version/.orig.tar.gz/}
    SRC=$generated
else
    if ! [ -f $SRC ]; then
        ./build-orig.sh $package $version
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
fi

if ! [ -f $SRC ]; then
    echo "Unable to get the origin tar ball for $package / $version."
    exit 1
fi

###############################################################################
### Set build version                                                       ###
###############################################################################
BUILD_DIR="/tmp/build-${package_lc}-$$"
mkdir $BUILD_DIR
ln -sf $CWD/$SRC $BUILD_DIR/$SRC

pushd $BUILD_DIR
tar xzf $CWD/$SRC
cd ${package_lc}-$version
cp -r $CWD/debian-${package_lc} debian

LAST_CHANGELOG_VERSION="$(dpkg-parsechangelog | awk -F ': ' '$1=="Version" {print $2}')"
NEW_BUILD_VERSION="$version-zentyal$rev"
if [ "$package" = "openchange" ]; then
    NEW_BUILD_VERSION="1:$version-zentyal$rev"
fi

dpkg --compare-versions $NEW_BUILD_VERSION gt $LAST_CHANGELOG_VERSION
BUILD_VERSION_GREATER=$?
dpkg --compare-versions $NEW_BUILD_VERSION eq $LAST_CHANGELOG_VERSION
BUILD_VERSION_EQUAL=$?

if [ $BUILD_VERSION_EQUAL -eq 0 ]; then
    # If build version is equal to the last changelog entry, ask for
    # confirmation before build but do not update changelog
    echo "Build version is equeal to last changelog entry:"
    echo "    Last changelog version: $LAST_CHANGELOG_VERSION"
    echo "    New build version:      $NEW_BUILD_VERSION"
    read -p "Continue? (y/n): "  CHOICE
    case "$CHOICE" in
      n|N ) exit 0;;
      y|Y ) ;;
      * ) exit 1;;
    esac
elif [ $BUILD_VERSION_GREATER -ne 0 ]; then
    # If build version is lower than last changelog entry, abort
    echo "Build version is older than last version in changelog:"
    echo "    Last changelog version: $LAST_CHANGELOG_VERSION"
    echo "    New build version:      $NEW_BUILD_VERSION"
    echo "Abort."
    exit 1
else
    # If build version is newer than last changelog entry, update changelog
    dch -b -v "$NEW_BUILD_VERSION" -D 'precise' --force-distribution 'New upstream release'
    cp debian/changelog $CWD/debian-${package_lc}/
fi


###############################################################################
### Build                                                                   ###
###############################################################################
ppa-build.sh
popd > /dev/null 2>&1

cp $BUILD_DIR/${package_lc}_*.{debian.tar.gz,dsc,changes} .

rm -rf $BUILD_DIR

exit 0
