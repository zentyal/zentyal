#!/bin/bash

TMPDIR=/tmp/zentyal-installer-$$
mkdir -p $TMPDIR

for i in core software
do
    dpkg-deb -e extras-*/zentyal-core_*.deb $TMPDIR/$i
done

DEPS=`grep ^Depends $TMPDIR/*/control | cut -d' ' -f2- | tr ',' "\n" | sed 's/^\s*//g' | sort | uniq | sed 's/mysql-server/mysql-client/' | tr "\n" ',' | sed 's/,/, /g'`

# Uncomment this to extract them as a plain space-separated list without versions or options
#DEPS=`grep ^Depends $TMPDIR/*/control | cut -d' ' -f2- | sed 's/([^)(]*)//g' | sed 's/|[^,]*//g' | tr ',' "\n" | sed 's/^\s*//g' | sort | uniq | sed 's/mysql-server/mysql-client/' | xargs`

rm -rf $TMPDIR

echo $DEPS
