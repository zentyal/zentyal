AC_DEFUN([AC_CONF_EBOX],
#
# Handle user hints
#
[
  AC_MSG_CHECKING(var path)
  VARPATH=`perl -MEBox::Config -e 'print EBox::Config->var'`
  if test -z "$VARPATH"; then
  	AC_MSG_ERROR("var path not found")
  fi
  AC_SUBST(VARPATH)
  AC_MSG_RESULT($VARPATH)

  AC_MSG_CHECKING(log path)
  LOGPATH=`perl -MEBox::Config -e 'print EBox::Config->log'`
  if test -z "$LOGPATH"; then
  	AC_MSG_ERROR("log  path  not found")
  fi
  AC_SUBST(LOGPATH)
  AC_MSG_RESULT($LOGPATH)
 
  AC_MSG_CHECKING(conf path)
  CONFPATH=`perl -MEBox::Config -e 'print EBox::Config->conf'`
  if test -z "$CONFPATH"; then
  	AC_MSG_ERROR("conf  path  not found")
  fi
  AC_SUBST(CONFPATH)
  AC_MSG_RESULT($CONFPATH)

  AC_MSG_CHECKING(etc path)
  ETCPATH=`perl -MEBox::Config -e 'print EBox::Config->etc'`
  if test -z "$ETCPATH"; then
  	AC_MSG_ERROR("etc path  not found")
  fi
  AC_SUBST(ETCPATH)
  AC_MSG_RESULT($ETCPATH) 

  AC_MSG_CHECKING(stubs path)
  STUBSPATH=`perl -MEBox::Config -e 'print EBox::Config->stubs'`
  if test -z "$STUBSPATH"; then
  	AC_MSG_ERROR("stubs  path  not found")
  fi
  AC_SUBST(STUBSPATH)
  AC_MSG_RESULT($STUBSPATH)

  AC_MSG_CHECKING(cgi path)
  CGIPATH=`perl -MEBox::Config -e 'print EBox::Config->cgi'`
  if test -z "$CGIPATH"; then
  	AC_MSG_ERROR("ebox cgi path not found")
  fi
  AC_SUBST(CGIPATH)
  AC_MSG_RESULT($CGIPATH)
  
  AC_MSG_CHECKING(templates path)
  TEMPLATESPATH=`perl -MEBox::Config -e 'print EBox::Config->templates'`
  if test -z "$CGIPATH"; then
  	AC_MSG_ERROR("ebox template path  not found")
  fi
  AC_SUBST(TEMPLATESPATH)
  AC_MSG_RESULT($TEMPLATESPATH)
  
  AC_MSG_CHECKING(schemas path)
  SCHEMASPATH=`perl -MEBox::Config -e 'print EBox::Config->schemas'`
  if test -z "$CGIPATH"; then
  	AC_MSG_ERROR("ebox schemas path  not found")
  fi
  AC_SUBST(SCHEMASPATH)
  AC_MSG_RESULT($SCHEMASPATH)
  
  AC_MSG_CHECKING(www path)
  WWWPATH=`perl -MEBox::Config -e 'print EBox::Config->www'`
  if test -z "$WWWPATH"; then
  	AC_MSG_ERROR("ebox www path  not found")
  fi
  AC_SUBST(WWWPATH)
  AC_MSG_RESULT($WWWPATH)

  AC_MSG_CHECKING(dynamic www path)
  DYNAMICWWWPATH=`perl -MEBox::Config -e 'print EBox::Config->dynamicwww'`
  if test -z "$DYNAMICWWWPATH"; then
  	AC_MSG_ERROR("ebox dynamic www path  not found")
  fi
  AC_SUBST(DYNAMICWWWPATH)
  AC_MSG_RESULT($DYNAMICWWWPATH)
  
  AC_MSG_CHECKING(css path)
  CSSPATH=`perl -MEBox::Config -e 'print EBox::Config->css'`
  if test -z "$CSSPATH"; then
  	AC_MSG_ERROR("ebox css path  not found")
  fi
  AC_SUBST(CSSPATH)
  AC_MSG_RESULT($CSSPATH)
  
  AC_MSG_CHECKING(images path)
  IMAGESPATH=`perl -MEBox::Config -e 'print EBox::Config->images'`
  if test -z "$IMAGESPATH"; then
  	AC_MSG_ERROR("ebox images path  not found")
  fi
  AC_SUBST(IMAGESPATH)
  AC_MSG_RESULT($IMAGESPATH)

  AC_MSG_CHECKING(dynamic images path)
  DYNAMICIMAGESPATH=`perl -MEBox::Config -e 'print EBox::Config->dynamicimages'`
  if test -z "$DYNAMICIMAGESPATH"; then
  	AC_MSG_ERROR("ebox images path  not found")
  fi
  AC_SUBST(DYNAMICIMAGESPATH)
  AC_MSG_RESULT($DYNAMICIMAGESPATH)

])
