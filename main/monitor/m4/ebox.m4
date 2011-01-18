AC_DEFUN([AC_CONF_EBOX],
#
# Handle user hints
#
[
  AC_MSG_CHECKING(conf path)
  CONFPATH=`perl -MEBox::Config -e 'print EBox::Config->conf'`
  if test -z "$CONFPATH"; then
  	AC_MSG_ERROR("conf path not found")
  fi
  AC_SUBST(CONFPATH)
  AC_MSG_RESULT($CONFPATH)
  
  AC_MSG_CHECKING(stubs path)
  STUBSPATH=`perl -MEBox::Config -e 'print EBox::Config->stubs'`
  if test -z "$STUBSPATH"; then
  	AC_MSG_ERROR("stubs path not found")
  fi
  AC_SUBST(STUBSPATH)
  AC_MSG_RESULT($STUBSPATH)

  AC_MSG_CHECKING(cgi path)
  CGIPATH=`perl -MEBox::Config -e 'print EBox::Config->cgi'`
  if test -z "$CGIPATH"; then
  	AC_MSG_ERROR("zentyal cgi path not found")
  fi
  AC_SUBST(CGIPATH)
  AC_MSG_RESULT($CGIPATH)
  
  AC_MSG_CHECKING(templates path)
  TEMPLATESPATH=`perl -MEBox::Config -e 'print EBox::Config->templates'`
  if test -z "$CGIPATH"; then
  	AC_MSG_ERROR("zentyal template path not found")
  fi
  AC_SUBST(TEMPLATESPATH)
  AC_MSG_RESULT($TEMPLATESPATH)
  
  AC_MSG_CHECKING(schemas path)
  SCHEMASPATH=`perl -MEBox::Config -e 'print EBox::Config->schemas'`
  if test -z "$CGIPATH"; then
  	AC_MSG_ERROR("zentyal schemas path not found")
  fi
  AC_SUBST(SCHEMASPATH)
  AC_MSG_RESULT($SCHEMASPATH)
  
  AC_MSG_CHECKING(www path)
  WWWPATH=`perl -MEBox::Config -e 'print EBox::Config->www'`
  if test -z "$CGIPATH"; then
  	AC_MSG_ERROR("zentyal www path not found")
  fi
  AC_SUBST(WWWPATH)
  AC_MSG_RESULT($WWWPATH)
  
  AC_MSG_CHECKING(css path)
  CSSPATH=`perl -MEBox::Config -e 'print EBox::Config->css'`
  if test -z "$CGIPATH"; then
  	AC_MSG_ERROR("zentyal css path not found")
  fi
  AC_SUBST(CSSPATH)
  AC_MSG_RESULT($CSSPATH)
  
  AC_MSG_CHECKING(images path)
  IMAGESPATH=`perl -MEBox::Config -e 'print EBox::Config->images'`
  if test -z "$CGIPATH"; then
  	AC_MSG_ERROR("zentyal images path not found")
  fi
  AC_SUBST(IMAGESPATH)
  AC_MSG_RESULT($IMAGESPATH)

])
