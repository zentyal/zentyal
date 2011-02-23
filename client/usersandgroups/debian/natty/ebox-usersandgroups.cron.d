# /etc/cron.d/ebox-usersandgroups

SHELL=/bin/sh
PATH=/usr/bin:/bin

# sync the slaves every 5 minutes if there are missing changes
*/5 * * * * root /usr/share/ebox-usersandgroups/slave-sync
