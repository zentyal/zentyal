## Process this file with automake to produce Makefile.in

crondir = @SYSCONFDIR@/cron.hourly

nobase_cron_SCRIPTS = 90zentyal-manage-logs zentyal.hourly

crondailydir = @SYSCONFDIR@/cron.daily

nobase_crondaily_SCRIPTS = zentyal.daily

EXTRA_DIST = $(nobase_cron_SCRIPTS) $(nobase_crondaily_SCRIPTS)

MAINTAINERCLEANFILES = Makefile.in

