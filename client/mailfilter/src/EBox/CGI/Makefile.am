## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/CGI/MailFilter

nobase_perl_DATA = Index.pm Enable.pm ChangePort.pm  ChangeAdminAddress.pm \
 ChangePolicy.pm \
AddAllowedMTA.pm RemoveAllowedMTA.pm EnableAntivirus.pm\
EnableAntispam.pm ChangeAntispamSettings.pm AddSenderACL.pm RemoveSenderACL.pm\
AntispamTraining.pm \
ChangeVDomainSettings.pm  \
FileFilterBase.pm ModifyFileFilterACL.pm \
  AddFileFilterElement.pm RemoveFileFilterElement.pm \
  RemoveAllFileFilterElements.pm	ChangeFileFilterDeniedElements.pm \
AddExternalDomain.pm RemoveExternalDomain.pm

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
