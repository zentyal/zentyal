## Process this file with automake to produce Makefile.in

Stubdir = @STUBSPATH@/squid

nobase_Stub_DATA = squid.conf.mas  \
	dansguardian.conf.mas dansguardianfN.conf.mas filtergroupslist.mas\
        exceptionsitelist.mas  bannedsitelist.mas  greysitelist.mas \
        bannedurllist.mas exceptionurllist.mas greyurllist.mas \
	bannedextensionlist.mas bannedmimetypelist.mas  \
	bannedregexpurllist.mas \
	bannedphraselist.mas exceptionphraselist.mas \
	clamdscan.conf.mas \
	pics.mas \
        ipgroups.mas \
	dansguardian.logrotate


EXTRA_DIST = $(nobase_Stub_DATA)

MAINTAINERCLEANFILES = Makefile.in
