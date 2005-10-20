#!/bin/sh

if [ -f Makefile ] ; then
	make maintainer-clean
fi

pushd ..
grep -h ^Description */debian/control | cut -c14- | sed s/^.*$/__\(\"\&\"\)\;/ > software/src/EBox/PackageDescriptions.pm
popd

mkdir -p po
./tools/po-am.generator > po/Makefile.am || exit 1
mkdir -p config
aclocal -I m4 || exit 1
autoconf || exit 1
automake --add-missing || exit 1
