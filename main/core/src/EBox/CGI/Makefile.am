## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/CGI

nobase_perl_DATA = ClientBase.pm ClientRawBase.pm WizardPage.pm \
            Finish.pm Menu.pm Progress.pm ProgressClient.pm Temp.pm \
            Wizard.pm Base.pm Run.pm MenuCSS.pm

SUBDIRS = Dashboard EBox Login Logout Logs Controller View Report ServiceModule t

SOURCES = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
