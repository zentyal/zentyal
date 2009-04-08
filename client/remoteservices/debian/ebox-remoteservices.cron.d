# /etc/cron.d/ebox-remoteservices: crontab entries for the ebox-remoteservices package

SHELL=/bin/sh
PATH=/usr/bin

# Get the clients and their eBox assigned to our VPN server each minute
0-59/15 * * * * root /usr/share/ebox/ebox-notify-mon-stats >> /var/log/ebox/ebox.log 2>&1
