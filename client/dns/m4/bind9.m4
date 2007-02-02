dnl Based on:
dnl http://www.gnu.org/software/ac-archive/htmldoc/ac_prog_apache.html
dnl Heavily modified for Ebox.
AC_DEFUN([AC_PROG_BIND9],
#
# Handle user hints
#
[
  if test -z "$BIND9PATH"; then
    AC_PATH_PROG(BIND9, named, , /usr/local/bind/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/opt/bind/bin:/opt/bind/sbin)
  else 
    AC_PATH_PROG(BIND9, named, , $BIND9PATH)
  fi
  AC_SUBST(BIND9)
  if test -z "$BIND9" ; then
      AC_MSG_ERROR("named executable not found");
  fi
  #
  # Collect apache version number. If for nothing else, this
  # guaranties that httpd is a working apache executable.
  #
  BIND9_READABLE_VERSION=`$BIND9 -v | sed -e 's/BIND //'`
  BIND9_VERSION=`echo $BIND9_READABLE_VERSION | sed -e 's/\.//g'`
  if test -z "$BIND9_VERSION" ; then
      AC_MSG_ERROR("could not determine bind version number");
  fi
  #
  # Find configuration directory
  #
  changequote(<<, >>)dnl
  BIND9CONFDIR="/etc/bind"
  changequote([, ])dnl
  BIND9CONF="$BIND9CONFDIR/named.conf"
  BIND9CONFOPTIONS="$BIND9CONFDIR/named.conf.options"
  BIND9CONFLOCAL="$BIND9CONFDIR/named.conf.local"
  AC_MSG_CHECKING(named.conf)
  AC_MSG_CHECKING(named.conf.options)
  AC_MSG_CHECKING(named.conf.local)

  if test -f "$BIND9CONF"
  then
    AC_MSG_RESULT(in $BIND9CONF)
  else
    AC_MSG_ERROR(bind configuration directory not found)
  fi
  #BIND9CONFDIR=`dirname $BIND9CONF`
  AC_SUBST(BIND9CONF)
  AC_SUBST(BIND9CONFDIR)
  AC_SUBST(BIND9CONFOPTIONS)
  AC_SUBST(BIND9CONFLOCAL)
  AC_PATH_PROG(BIND9_INIT, bind9, , /etc/init.d)
  if test -z "$BIND9_INIT" ; then
  	AC_MSG_ERROR("bind init script not found")
  fi	
  AC_SUBST(BIND9_INIT)
])
