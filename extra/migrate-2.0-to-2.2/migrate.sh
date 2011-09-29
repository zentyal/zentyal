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
set -e

if [ ! "$UID" -eq "0" ] ; then
    echo Sorry, you must be root to run this script >&2
    exit 1
fi

ZENTYAL_PPA="ppa.launchpad.net\/zentyal"
sed -i "s/$ZENTYAL_PPA\/2.0/$ZENTYAL_PPA\/2.2/g" /etc/apt/sources.list

# FIXME: what happens with usercorner? Detect it if exists usercorner.bak?
# Maybe it's better to detect this via the *.bak files instead of dpkg?
EBOX_PACKAGES=`dpkg -l | grep 'ebox-' | awk '{ print $2 }'`
INSTALLED_MODULES=`dpkg -l | grep ^ii | grep 'ebox-' | awk '{ print $2 }' | sed 's/andgroups//g' | sed 's/ebox-//g' | grep -v 'cloud-prof'`

echo "The following modules have been detected and are going to be upgraded:"
echo $INSTALLED_MODULES
echo
echo "Press return to continue or Control+C to cancel..."
read


function retry {
    set +e
    $@
    while [[ $? -ne 0 ]] ; do
        echo "Command FAILED! Please check your internet connectivity"
        echo "press return to continue or Control+C to abort"
        read
        $@
    done
    set -e
}


# TODO disable QA updates and upgrade to last 2.0 packages (to execute migrations)

# Pre remove scripts
run-parts ./pre-remove

# Restore network connectivity after ebox stop (we will need it for apt commands)
echo -e "invoke-rc.d ebox network start || true" >> /var/lib/dpkg/info/ebox.prerm
echo -e "invoke-rc.d ebox apache stop || true" >> /var/lib/dpkg/info/ebox.prerm
# TODO: not sure if this is necessary, probably the above apache stop
# will be enough
echo -e "pkill -9 redis-server || true" >> /var/lib/dpkg/info/ebox.prerm
retry "apt-get remove libebox -y --force-yes"

retry "apt-get update"
LANG=C DEBIAN_FRONTEND=noninteractive retry "apt-get dist-upgrade -y --force-yes"

for i in $INSTALLED_MODULES
do
    PACKAGES="$PACKAGES zentyal-$i"
done
LANG=C DEBIAN_FRONTEND=noninteractive retry "apt-get install -o DPkg::Options::="--force-confold" --no-install-recommends -y --force-yes $PACKAGES"
/etc/init.d/zentyal stop


# Run all the scripts to migrate data from 2.0 to 2.2
run-parts ./post-upgrade

# purge ebox 2.0
for i in $(ls /var/lib/dpkg/info/ebox*.postrm /var/lib/dpkg/info/libebox.postrm)
do
    echo -e "#!/bin/bash\nexit 0" > $i
done
dpkg --purge libebox ebox $EBOX_PACKAGES

/etc/init.d/zentyal start

echo "Migration finished. You can start using Zentyal 2.2 now!"
