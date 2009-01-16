## Process this file with automake to produce Makefile.in

SUBDIRS = ajax common dashboard login logout logs report RemoteServices

templatedir = $(datadir)/ebox/templates
template_DATA = backup.mas bug.mas confirm-backup.mas  backupTabs.mas \
        finish.mas general.mas \
	halt.mas password.mas port.mas progress.mas \
	 header.mas headTitle.mas footer.mas headerWithRefresh.mas\
	dataInUse.mas configurationFiles.mas  configureView.mas  moduleStatus.mas \
	moduleStatusTable.mas notConfigured.mas

EXTRA_DIST = $(template_DATA)

MAINTAINERCLEANFILES = Makefile.in
