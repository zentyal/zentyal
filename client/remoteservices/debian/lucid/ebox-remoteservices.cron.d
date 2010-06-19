# /etc/cron.d/ebox-remoteservices: crontab entries for the ebox-remoteservices package

SHELL=/bin/sh
PATH=/usr/bin:/bin

# Run the cron jobs sent by eBox CC
0-59/10 * * * * root /usr/share/ebox/ebox-cronjob-runner >> /dev/null 2>&1
# Get the new cron jobs from eBox CC
10 3 * * * root /usr/share/ebox/ebox-get-cronjobs >> /dev/null 2>&1
# Run the automatic backup
32 2 * * * root /usr/share/ebox/ebox-automatic-conf-backup > /dev/null 2>&1
# Get a new bundle if available from eBox CC each week
45 4 * * 7 root /usr/share/ebox/ebox-reload-bundle > /dev/null 2>&1
