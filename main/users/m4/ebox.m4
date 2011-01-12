AC_DEFUN([AC_CONF_EBOX],
#
# Handle user hints
#
[
  real_test=$1


  if test "x$real_test" = "xyes" ; then
	  AC_MSG_CHECKING(conf path)
	  CONFPATH=`perl -MEBox::Config -e 'print EBox::Config->conf'`
  else
          CONFPATH=$LOCALSTATEDIR/lib/ebox/conf
  fi
  AC_SUBST(CONFPATH)
  AC_MSG_RESULT($CONFPATH)
   
   if test "x$real_test" = "xyes" ; then
	  AC_MSG_CHECKING(var path)
	  VARPATH=`perl -MEBox::Config -e 'print EBox::Config->var'`
  else
          VARPATH=$LOCALSTATEDIR
  fi
  AC_SUBST(VARPATH)
  AC_MSG_RESULT($VARPATH)
 
  if test "x$real_test" = "xyes" ; then
	AC_MSG_CHECKING(stubs path)
	STUBSPATH=`perl -MEBox::Config -e 'print EBox::Config->stubs'`

	AC_MSG_CHECKING(cgi path)
	CGIPATH=`perl -MEBox::Config -e 'print EBox::Config->cgi'`

	AC_MSG_CHECKING(templates path)
	TEMPLATESPATH=`perl -MEBox::Config -e 'print EBox::Config->templates'`

	AC_MSG_CHECKING(schemas path)
	SCHEMASPATH=`perl -MEBox::Config -e 'print EBox::Config->schemas'`

	AC_MSG_CHECKING(www path)
	WWWPATH=`perl -MEBox::Config -e 'print EBox::Config->www'`
	if test -z "$CGIPATH"; then
	AC_MSG_ERROR("ebox www path  not found")
	fi
	AC_SUBST(WWWPATH)
	AC_MSG_RESULT($WWWPATH)

	AC_MSG_CHECKING(css path)
	CSSPATH=`perl -MEBox::Config -e 'print EBox::Config->css'`

	AC_MSG_CHECKING(images path)
	IMAGESPATH=`perl -MEBox::Config -e 'print EBox::Config->images'`
  else
    STUBSPATH=$DATADIR/ebox/stubs
    CGIPATH=$DATADIR/ebox/cgi
    TEMPLATESPATH=$DATADIR/ebox/templates
    SCHEMASPATH=$DATADIR/ebox/schemas
    WWWPATH=$DATADIR/ebox/www
    CSSPATH=$DATADIR/ebox/www/css
    IMAGESPATH=$DATADIR/ebox/www/images
  fi

  if test -z "$STUBSPATH"; then
	AC_MSG_ERROR("stubs  path  not found")
  fi
  AC_SUBST(STUBSPATH)
  AC_MSG_RESULT($STUBSPATH)

  if test -z "$CGIPATH"; then
    AC_MSG_ERROR("ebox cgi path not found")
  fi
  AC_SUBST(CGIPATH)
  AC_MSG_RESULT($CGIPATH)

  if test -z "$CGIPATH"; then
    AC_MSG_ERROR("ebox template path  not found")
  fi
  AC_SUBST(TEMPLATESPATH)
  AC_MSG_RESULT($TEMPLATESPATH)

  if test -z "$CGIPATH"; then
    AC_MSG_ERROR("ebox schemas path  not found")
  fi
  AC_SUBST(SCHEMASPATH)
  AC_MSG_RESULT($SCHEMASPATH)

  if test -z "$CGIPATH"; then
    AC_MSG_ERROR("ebox css path  not found")
  fi
  AC_SUBST(CSSPATH)
  AC_MSG_RESULT($CSSPATH)

  if test -z "$CGIPATH"; then
    AC_MSG_ERROR("ebox images path  not found")
  fi
  AC_SUBST(IMAGESPATH)
  AC_MSG_RESULT($IMAGESPATH)

])
