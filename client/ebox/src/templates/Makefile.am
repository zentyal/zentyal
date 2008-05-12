## Process this file with automake to produce Makefile.in

SUBDIRS = ajax common login logout logs firstTime report

templatedir = $(datadir)/ebox/templates
template_DATA = backup.mas bug.mas confirm-backup.mas finish.mas general.mas \
	halt.mas password.mas port.mas progress.mas \
	 header.mas headTitle.mas footer.mas \
	dataInUse.mas configurationFiles.mas  configureView.mas  moduleStatus.mas \
	moduleStatusTable.mas notConfigured.mas

EXTRA_DIST = $(template_DATA)

MAINTAINERCLEANFILES = Makefile.in
