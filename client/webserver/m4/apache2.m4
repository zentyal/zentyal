dnl Based on:
dnl http://www.gnu.org/software/ac-archive/htmldoc/ac_prog_apache.html
dnl Heavily modified for Ebox.
AC_DEFUN([AC_PROG_APACHE2],
#
# Handle user hints
#
[
  if test -z "$APACHE2PATH"; then
    AC_PATH_PROG(APACHE2EXECPATH, apache2, , /usr/local/apache2/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/opt/apache2/bin:/opt/apache2/sbin)
  else 
    AC_PATH_PROG(APACHE2EXECPATH, apache2, , $APACHE2PATH)
  fi
  AC_SUBST(APACHE2EXECPATH)
  if test -z "$APACHE2EXECPATH" ; then
      AC_MSG_ERROR("apache2 executable not found");
  fi
  #
  #
  # Find configuration directory
  #
  changequote(<<, >>)dnl
  APACHE2CONFDIRPATH="/etc/apache2"
  changequote([, ])dnl
  APACHE2PORTS="$APACHE2CONFDIRPATH/ports.conf"
  APACHE2MODSAVAILABLE="$APACHE2CONFDIRPATH/mods-available"
  APACHE2MODSENABLED="$APACHE2CONFDIRPATH/mods-enabled"
  AC_MSG_CHECKING(ports.conf)
  AC_MSG_CHECKING(mods-available)
  AC_MSG_CHECKING(mods-enabled)

  if test -f "$APACHE2CONFDIRPATH"
  then
    AC_MSG_RESULT(in $APACHE2CONFDIRPATH)
  else
    AC_MSG_ERROR(apache2 configuration directory not found)
  fi
  AC_SUBST(APACHE2PORTS)
  AC_SUBST(APACHE2CONFDIRPATH)
  AC_SUBST(APACHE2MODSAVAILABLE)
  AC_SUBST(APACHE2MODSENABLED)
  AC_PATH_PROG(APACHE2_INIT, apache2, , /etc/init.d)
  if test -z "$APACHE2_INIT" ; then
  	AC_MSG_ERROR("apache2 init script not found")
  fi	
  AC_SUBST(APACHE2_INIT)
  AC_SUBST(APACHE2DOCROOT)
])
