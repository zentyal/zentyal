#!/bin/sh

# Disable auto login once installation is done
sed -i "s/auto_login.*/auto_login\tno/" /etc/slim.conf

# Restore original rc.local and clean stuff
mv /var/tmp/ebox/rc.local /etc/rc.local
rm -rf /var/tmp/ebox

exit 0
