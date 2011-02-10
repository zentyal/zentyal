## Process this file with automake to produce Makefile.in

scriptsdir = @DATADIR@/zentyal-remoteservices

scripts_SCRIPTS = initial-setup automatic-conf-backup cronjob-runner get-cronjobs \
		  finish-script-session notify-job reload-bundle \
		  runnerd start-script-session unsubscribe

helperscriptsdir = @DATADIR@/zentyal-remoteservices

helperscripts_SCRIPTS = john-wrapper rrd-dumper remote-support.keys \
			password-checker.pl subs-level valid-users.pl

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(scripts_SCRIPTS) $(helperscripts_SCRIPTS)
