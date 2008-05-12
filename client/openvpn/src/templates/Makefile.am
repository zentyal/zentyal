## Process this file with automake to produce Makefile.in
SUBDIRS=t

templatedir = @TEMPLATESPATH@/openvpn

template_DATA =  index.mas \
                 create.mas edit.mas delete.mas serverProperties.mas \
                 caRequired.mas \
                 createClient.mas editClient.mas clientProperties.mas fixedTdFormTable.mas\
                 clientBundle.mas

EXTRA_DIST = $(template_DATA)

MAINTAINERCLEANFILES = Makefile.in
