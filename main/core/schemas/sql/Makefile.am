## Process this file with automake to produce Makefile.in

SUBDIRS = period

Sqldir = @DATADIR@/zentyal/sql/

nobase_Sql_DATA = admin.sql audit_actions.sql audit_sessions.sql consolidation.sql events.sql events_report.sql report_consolidation.sql sysinfo_disk_usage.sql sysinfo_disk_usage_report.sql backup_slices.sql

EXTRA_DIST = $(nobase_Sql_DATA)

MAINTAINERCLEANFILES = Makefile.in
