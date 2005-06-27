dnl Based on:
dnl http://www.gnu.org/software/ac-archive/htmldoc/ac_prog_apache.html
dnl Heavily modified for Ebox.
AC_DEFUN([AC_PROG_DHCP],
#
# Handle user hints
#
[
  if test -z "$DHCPPATH"; then
    AC_PATH_PROG(DHCP, dhcpd3, , /usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin)
  else 
    AC_PATH_PROG(DHCP, dhcpd3, , $DHCPPATH)
  fi
  AC_SUBST(DHCP)
  if test -z "$DHCP" ; then
      AC_MSG_ERROR("dhcpd3 executable not found");
  fi
  #
  # Collect apache version number. If for nothing else, this
  # guaranties that httpd is a working apache executable.
  #
  DHCP_VERSION=`$DHCP --version 2>&1`
  if test -z "$DHCP_VERSION" ; then
      AC_MSG_ERROR("could not determine dhcpd version number");
  fi
  #
  # Find configuration directory
  #
  AC_PATH_PROG(DHCP_INIT, dhcp3-server, , /etc/init.d)
  if test -z "$DHCP_INIT" ; then
  	AC_MSG_ERROR("dhcp3 init script not found")
  fi	
  AC_SUBST(DHCP_INIT)
])
