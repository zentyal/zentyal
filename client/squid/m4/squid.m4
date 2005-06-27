dnl Based on:
dnl http://www.gnu.org/software/ac-archive/htmldoc/ac_prog_apache.html
dnl Heavily modified for Ebox.
AC_DEFUN([AC_PROG_SQUID],
#
# Handle user hints
#
[
  if test -z "$SQUIDPATH"; then
    AC_PATH_PROG(SQUID, squid, , /usr/local/squid/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/opt/squid/bin:/opt/squid/sbin:/opt/squid/bin:/opt/squid/sbin)
  else 
    AC_PATH_PROG(SQUID, squid, , $SQUIDPATH)
  fi
  AC_SUBST(SQUID)
  if test -z "$SQUID" ; then
      AC_MSG_ERROR("squid executable not found");
  fi
  #
  # Collect apache version number. If for nothing else, this
  # guaranties that httpd is a working apache executable.
  #
  SQUID_READABLE_VERSION=`$SQUID -v | grep 'Version' | sed -e 's/Squid.*Version *//'`
  SQUID_VERSION=`echo $SQUID_READABLE_VERSION | sed -e 's/\.//g'`
  if test -z "$SQUID_VERSION" ; then
      AC_MSG_ERROR("could not determine squid version number");
  fi
  #
  # Find configuration directory
  #
  changequote(<<, >>)dnl
  SQUIDCONF=`$SQUID -v | grep ^configure |  sed -e 's/.*sysconfdir=\([^ ]*\).*/\1/'`
  changequote([, ])dnl
  SQUIDCONF="$SQUIDCONF/squid.conf"
  AC_MSG_CHECKING(squid.conf)
  if test -f "$SQUIDCONF"
  then
    AC_MSG_RESULT(in $SQUIDCONF)
  else
    AC_MSG_ERROR(squid configuration directory not found)
  fi
  #SQUIDCONFDIR=`dirname $SQUIDCONF`
  AC_SUBST(SQUIDCONF)
  AC_PATH_PROG(SQUID_INIT, squid, , /etc/init.d)
  if test -z "$SQUID_INIT" ; then
  	AC_MSG_ERROR("squid init script not found")
  fi	
  AC_SUBST(SQUID_INIT)
])
