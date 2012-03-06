#!/bin/sh

set -e

# install zentyal core and software
DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y --force-yes zentyal

/usr/share/zenbuntu-desktop/x11-setup

mv /usr/share/zenbuntu-desktop/second-boot.sh /etc/rc.local

initctl emit zentyal-lxdm

exit 0
