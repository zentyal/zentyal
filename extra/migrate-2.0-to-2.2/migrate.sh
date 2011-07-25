#!/bin/bash
#
# Copyright (C) 2011 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# TODO: Check we have root permissions, ask to execute with sudo otherwise

ZENTYAL_PPA="ppa.launchpad.net\/zentyal"
sed -i "s/$ZENTYAL_PPA\/2.0/$ZENTYAL_PPA\/2.1/g" /etc/apt/sources.list

# FIXME: what happens with usercorner? Detect it if exists usercorner.bak?
# Maybe it's better to detect this via the *.bak files instead of dpkg?
INSTALLED_MODULES=`dpkg -l | grep 'ebox-' | awk '{ print $2 }' | sed 's/andgroups//g' | sed 's/ebox-//g'`

echo "The following modules have been detected and are going to be upgraded:"
echo $INSTALLED_MODULES
echo
echo "Press return to continue or Control+C to cancel..."
read

apt-get remove libebox

apt-get update
apt-get dist-upgrade

for i in $INSTALLED_MODULES ; do echo "zentyal-$i"; done | xargs apt-get install --no-install-recommends

/etc/init.d/zentyal stop

# Run all the scripts to migrate data from 2.0 to 2.2
run-parts ./lib

dpkg --purge libebox ebox ebox-.* # FIXME: check this (grep ^rc ...)

/etc/init.d/zentyal start

echo "Migration finished. You can start using Zentyal 2.2 now!"
