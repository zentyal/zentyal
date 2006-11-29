#!/bin/bash

# Script to execute after debian installer base-config and before
# showing login indicator and debian sarge is ready to be fucked up

# Install ebox-packages and ssh without user interaction
export DEBIAN_FRONTEND=noninteractive

apt-get -y install "^ebox-.*" ssh 

# Copy eBox Debian source list to installed system
cp /etc/apt/sources.list.ebox /etc/apt/sources.list

# Move eBox packages to where in a Debian system stored
mv /var/tmp/*ebox*.deb /var/cache/apt/archives/

# Append eBox support languages to generate to current supported
# locales
cat /var/tmp/locale.gen >> /etc/locale.gen

# Regenerate locales to update the new messages from eBox
/usr/sbin/locale-gen ; /usr/sbin/locale-gen

# In order to infere correct locale for an eBox user when debian
# installer select a locale supported by eBox and not standard one

# LANG selected by debian installer
debianInstLANG=$(echo $LANG | cut -c1-5)

# Find locale supported by eBox (only ISO 639-1 acceptable and exact
# match such as en_US or es_AR.
(grep UTF-8 /var/tmp/locale.gen | cut -d\. -f 1 | grep -q $debianInstLANG) \
 && echo -n $debianInstLANG.UTF-8 > /var/lib/ebox/conf/locale

# Change owner to ebox to let eBox change it
chown ebox.ebox /var/lib/ebox/conf/locale

# Remove undesirable stuff
rm -f /var/tmp/locale.gen

# Run ebox-software in order to update packages list (which is done
# nightly)
echo "Updating package list"
ebox-software
