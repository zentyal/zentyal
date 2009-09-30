## Process this file with automake to produce Makefile.in

scriptsdir = @DATADIR@/ebox

scripts_SCRIPTS = ebox-cronjob-runner ebox-get-cronjobs ebox-finish-script-session \
		  ebox-notify-job ebox-notify-mon-stats \
	          ebox-runnerd ebox-start-script-session \
	          ebox-unsubscribe

helperscriptsdir = @DATADIR@/ebox-remoteservices

helperscripts_SCRIPTS = rrd-dumper

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(scripts_SCRIPTS) $(helperscripts_SCRIPTS)
