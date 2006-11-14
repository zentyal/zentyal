#!/bin/bash

# Install files in /install and some in /doc
# 26-dec-99 changes for i386 (2.2.x) bootdisks --jwest
# 11-mar-00 added sparc to boot-disk documentation test  --jwest

set -e

# The location of the tree for CD#1, passed in
DIR=$1

DOCDIR=doc

# Put the install documentation in /install
cd $DIR/dists/$CODENAME/main/disks-$ARCH/current/$DOCDIR
mkdir $DIR/install/$DOCDIR
cp -a * $DIR/install/$DOCDIR/
ln -sf install.en.html $DIR/install/$DOCDIR/index.html

# Put the boot-disk documentation in /doc too
mkdir $DIR/doc/install
cd $DIR/doc/install
for file in ../../install/$DOCDIR/*.{html,txt}
do
	ln -s $file
done

