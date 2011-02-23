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

  DHCPDCONF="/etc/dhcp3/dhcpd.conf" 
  DHCPDLEASES="/var/lib/dhcp3/dhcpd.leases" 
  DHCPDPID="/var/run/dhcp3-server/dhcpd.pid" 
  DHCPD_SERVICE="ebox.dhcpd3" 
  DHCPD_INIT="/etc/init.d/dhcp3-server" 
  DHCPD_INIT_SERVICE="dhcp3-server" 

  AC_SUBST(DHCP_INIT)
  AC_SUBST(DHCPDCONF)
  AC_SUBST(DHCPDLEASES)
  AC_SUBST(DHCPDPID)
  AC_SUBST(DHCPD_SERVICE)
  AC_SUBST(DHCPD_INIT)
  AC_SUBST(DHCPD_INIT_SERVICE)
])
