#!/bin/sh

# FOR POTATO
# Include upgrade* dir when available

set -e

for arch in i386 alpha sparc m68k
do
  if [ "$ARCH" = "$arch" -a -d "$MIRROR/dists/$CODENAME/main/upgrade-$ARCH" ];
  then
    for dir in $TDIR/$CODENAME-$ARCH/CD1*
    do
      cp -a $MIRROR/dists/$CODENAME/main/upgrade-$ARCH $dir/
      mv $dir/upgrade-$ARCH $dir/upgrade
    done
  fi
done

exit 0

