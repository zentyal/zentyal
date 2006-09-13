SUBDIRS =  rootTests
## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/Backup

nobase_perl_DATA = BackupManager.pm  TarArchive.pm OpticalDiscDrives.pm

test_classes = Test.pm

DISTCLEANFILES = 

EXTRA_DIST = $(nobase_perl_DATA) $(test_classes)

MAINTAINERCLEANFILES = Makefile.in
