#!/bin/bash
#
# Copyright (C) 2011-2012 eBox Technologies S.L.
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
set -e

if [ ! "$UID" -eq "0" ] ; then
    echo Sorry, you must be root to run this script >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

function ask_confirmation {
    echo
    echo "Press return to continue or Control+C to abort..."
    read
}

function retry {
    set +e
    $@
    while [[ $? -ne 0 ]] ; do
        echo "Command FAILED! Please check your internet connectivity"
        ask_confirmation
        $@
    done
    set -e
}

DIST_UPGRADE="apt-get dist-upgrade -y --force-yes"

echo "Before starting the migration process all the packages of the"
echo "Zentyal 2.0 system need to be upgraded to the latest versions"
ask_confirmation

rm -f /etc/apt/sources.list.d/*ebox*
rm -f /etc/apt/preferences.d/*ebox*
retry "apt-get update"
retry $DIST_UPGRADE

EBOX_PACKAGES=`dpkg -l | grep 'ebox-' | awk '{ print $2 }'`
INSTALLED_MODULES=`dpkg -l | grep ^ii | grep 'ebox-' | awk '{ print $2 }' | sed 's/andgroups//g' | sed 's/ebox-//g' | grep -v 'cloud-prof'`

echo
echo "Zentyal 2.0 upgrade finished. You should check now if everything is"
echo "working properly before starting the migration to Zentyal 2.2."
echo
echo "The following modules have been detected and are going to be upgraded:"
echo $INSTALLED_MODULES
ask_confirmation

ZENTYAL_PPA="ppa.launchpad.net\/zentyal"
sed -i "s/$ZENTYAL_PPA\/2.0/$ZENTYAL_PPA\/2.2/g" /etc/apt/sources.list

retry "apt-get install -o DPkg::Options::="--force-confold" --no-install-recommends -y --force-yes libyaml-libyaml-perl"

# Pre remove scripts
run-parts ./pre-remove

# prevent cloud unsubscription during remove
RS_PRERM=/var/lib/dpkg/info/ebox-remoteservices.prerm
[ -f $RS_PRERM ] && echo -e "#!/bin/bash\nexit 0" > $RS_PRERM

# remove Zentyal 2.0 packages
retry "apt-get remove libebox -y --force-yes"

# kill processes belonging to ebox user
for i in ad-pwdsync apache2-user redis-usercorner runnerd apache-perl redis learnspamd
do
    stop ebox.$i || true
done

# this cron stuff is not deleted after purge, so we get rid of it now
rm -f /etc/cron.d/ebox-*
# delete also duplicity cache, it will be stored under /var/cache in 2.2
rm -rf /var/lib/{ebox,zentyal}/.cache/duplicity

retry "apt-get update"
retry $DIST_UPGRADE

for i in $INSTALLED_MODULES
do
    PACKAGES="$PACKAGES zentyal-$i"
done
retry "apt-get install -o DPkg::Options::="--force-confold" --no-install-recommends -y --force-yes $PACKAGES"
/etc/init.d/zentyal stop

# Run all the scripts to migrate data from 2.0 to 2.2
run-parts ./post-upgrade || true

# purge Zentyal 2.0
for i in $(ls /var/lib/dpkg/info/ebox*.postrm /var/lib/dpkg/info/libebox.postrm)
do
    echo -e "#!/bin/bash\nexit 0" > $i
done
dpkg --purge libebox ebox $EBOX_PACKAGES

/etc/init.d/zentyal start

echo
echo "Migration finished. You can start using Zentyal 2.2 now!"
