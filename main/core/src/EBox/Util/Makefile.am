## Process this file with automake to produce Makefile.in
perldir = @PERLPATH@/EBox/Util

mods = BugReport.pm Lock.pm Nmap.pm Version.pm Software.pm SQL.pm SystemKernel.pm \
       GPG.pm Init.pm

nobase_perl_DATA = $(mods)

SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(mods)

MAINTAINERCLEANFILES = Makefile.in
