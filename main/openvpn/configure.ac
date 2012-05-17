AC_INIT([zentyal-openvpn], [2.2.2])

AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([src/EBox/OpenVPN.pm])

AM_INIT_AUTOMAKE([foreign])

AM_MAINTAINER_MODE

AC_DEFINE_DIR(DATADIR, datadir)
AC_DEFINE_DIR(LIBDIR, libdir)

AC_ARG_ENABLE([runtime-tests],
	[ --disable-runtime-tests	Do not try to test runtime dependencies],
	,
	enable_runtime_tests=yes)

if test "x$enable_runtime_tests" = "xyes" ; then
	AC_CHECK_PROG(PERL, perl, perl, none)

	if test "$PERL" = "none" ; then
		AC_MSG_ERROR(perl not found)
	fi

	perlpath=`$PERL -e 'foreach (@INC) { print "$_\n";}' | grep "^$DATADIR" | head -1`
	if test -z "$perlpath" ; then
	perlpath=`$PERL -e 'foreach (@INC) { print "$_\n";}' | grep "^$prefix" | head -1`
	fi

	AC_CONF_EBOX
fi

if test -z "$perlpath" ; then
	perlpath="$DATADIR/perl5/"
	AC_MSG_NOTICE([Perl libraries will be installed in $perlpath, make sure to
	include it in your path])
else
	AC_MSG_NOTICE([Perl libraries will be installed in $perlpath])
fi

AC_DEFINE_DIR(PERLPATH, perlpath)

AC_CONFIG_FILES([
conf/Makefile
src/Makefile
src/EBox/Makefile
src/EBox/t/Makefile
src/EBox/t/testdata/Makefile
src/EBox/OpenVPN/Makefile
src/EBox/OpenVPN/Model/Makefile
src/EBox/OpenVPN/Model/Servers/Makefile
src/EBox/OpenVPN/Model/ServerConfiguration/Makefile
src/EBox/OpenVPN/Model/t/Makefile
src/EBox/OpenVPN/Types/Makefile
src/EBox/OpenVPN/Server/Makefile
src/EBox/OpenVPN/Server/t/Makefile
src/EBox/OpenVPN/Server/ClientBundleGenerator/Makefile
src/EBox/OpenVPN/Server/ClientBundleGenerator/EBoxToEBox/Makefile
src/EBox/OpenVPN/Server/ClientBundleGenerator/t/Makefile
src/EBox/OpenVPN/Client/Makefile
src/EBox/OpenVPN/Client/t/Makefile
src/EBox/OpenVPN/Client/t/testdata/Makefile
src/EBox/OpenVPN/LogHelper/Makefile
src/EBox/OpenVPN/t/Makefile
src/scripts/Makefile
src/scripts/installer/Makefile
schemas/Makefile
schemas/urls/Makefile
stubs/Makefile
stubs/quagga/Makefile
schemas/sql/Makefile
Makefile
])

AC_OUTPUT
