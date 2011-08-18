## Process this file with automake to produce Makefile.in

scriptsdir = @DATADIR@/ebox

scripts_SCRIPTS = ebox-automatic-conf-backup ebox-cronjob-runner ebox-get-cronjobs \
		  ebox-finish-script-session ebox-notify-job ebox-reload-bundle \
		  ebox-runnerd ebox-start-script-session ebox-unsubscribe 

helperscriptsdir = @DATADIR@/ebox-remoteservices

helperscripts_SCRIPTS = john-wrapper rrd-dumper remote-support.keys \
			password-checker.pl subs-level valid-users.pl \
			route-up-support-access

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(scripts_SCRIPTS) $(helperscripts_SCRIPTS)
