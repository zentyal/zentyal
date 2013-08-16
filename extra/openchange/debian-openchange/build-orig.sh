#!/bin/sh
# Build a source tarball for openchange

openchange_repos=svn+https://svn.openchange.org/openchange
version=$( dpkg-parsechangelog -l`dirname $0`/changelog | sed -n 's/^Version: \(.*:\|\)//p' | sed 's/-[0-9.]\+$//' )

if test -z "$BRANCH"; then
	BRANCH="trunk"
else
	BRANCH="branches/$BRANCH"
fi

if echo $version | grep bzr > /dev/null; then
	# Snapshot
	revno=`echo $version | sed 's/^[0-9.]\+[+~]bzr//'`
	bzr export -r$revno openchange-$version $openchange_repos/$BRANCH 
	cd openchange-$version && ./autogen.sh && cd ..
	tar cvz openchange-$version > openchange_$version.orig.tar.gz
	rm -rf openchange-$version
else
	uscan --upstream-version $version
fi
