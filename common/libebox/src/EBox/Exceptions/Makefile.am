## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/Exceptions

nobase_perl_DATA = Base.pm InvalidData.pm DataExists.pm External.pm \
	DataNotFound.pm DataMissing.pm Internal.pm Lock.pm NotImplemented.pm \
	DataInUse.pm MissingArgument.pm DeprecatedMethod.pm

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
