#
# $Id: aclocal.m4,v 1.4 2003/06/23 18:26:58 mx2002 Exp $
#

dnl AC_VALIDATE_CACHE_SYSTEM_TYPE[(cmd)]
dnl if the cache file is inconsistent with the current host,
dnl target and build system types, execute CMD or print a default
dnl error message.
AC_DEFUN(AC_VALIDATE_CACHE_SYSTEM_TYPE, [
    AC_REQUIRE([AC_CANONICAL_SYSTEM])
    AC_MSG_CHECKING([config.cache system type])
    if { test x"${ac_cv_host_system_type+set}" = x"set" &&
         test x"$ac_cv_host_system_type" != x"$host"; } ||
       { test x"${ac_cv_build_system_type+set}" = x"set" &&
         test x"$ac_cv_build_system_type" != x"$build"; } ||
       { test x"${ac_cv_target_system_type+set}" = x"set" &&
         test x"$ac_cv_target_system_type" != x"$target"; }; then
	AC_MSG_RESULT([different])
	ifelse($#, 1, [$1],
		[AC_MSG_ERROR(["you must remove config.cache and restart configure"])])
    else
	AC_MSG_RESULT([same])
    fi
    ac_cv_host_system_type="$host"
    ac_cv_build_system_type="$build"
    ac_cv_target_system_type="$target"
])

dnl Mark specified module as shared
dnl SMB_MODULE(name,static_files,shared_files,subsystem,whatif-static,whatif-shared)
AC_DEFUN(SMB_MODULE,
[
	AC_MSG_CHECKING([how to build $1])
	if test "$[MODULE_][$1]"; then
		DEST=$[MODULE_][$1]
	elif test "$[MODULE_]translit([$4], [A-Z], [a-z])" -a "$[MODULE_DEFAULT_][$1]"; then
		DEST=$[MODULE_]translit([$4], [A-Z], [a-z])
	else
		DEST=$[MODULE_DEFAULT_][$1]
	fi
	
	if test x"$DEST" = xSHARED; then
		AC_DEFINE([$1][_init], [init_module], [Whether to build $1 as shared module])
		$4_MODULES="$$4_MODULES $3"
		AC_MSG_RESULT([shared])
		[$6]
	elif test x"$DEST" = xSTATIC; then
		[init_static_modules_]translit([$4], [A-Z], [a-z])="$[init_static_modules_]translit([$4], [A-Z], [a-z]) $1_init();"
		string_static_modules="$string_static_modules $1"
		$4_STATIC="$$4_STATIC $2"
		AC_SUBST($4_STATIC)
		[$5]
		AC_MSG_RESULT([static])
	else
		AC_MSG_RESULT([not])
	fi
	MODULES_CLEAN="$MODULES_CLEAN $2 $3"
])

AC_DEFUN(SMB_SUBSYSTEM,
[
	AC_SUBST($1_STATIC)
	AC_SUBST($1_MODULES)
	AC_DEFINE_UNQUOTED([static_init_]translit([$1], [A-Z], [a-z]), [{$init_static_modules_]translit([$1], [A-Z], [a-z])[}], [Static init functions])
])

dnl AC_PROG_CC_FLAG(flag)
AC_DEFUN(AC_PROG_CC_FLAG,
[AC_CACHE_CHECK(whether ${CC-cc} accepts -$1, ac_cv_prog_cc_$1,
[echo 'void f(){}' > conftest.c
if test -z "`${CC-cc} -$1 -c conftest.c 2>&1`"; then
  ac_cv_prog_cc_$1=yes
else
  ac_cv_prog_cc_$1=no
fi
rm -f conftest*
])])

dnl see if a declaration exists for a function or variable
dnl defines HAVE_function_DECL if it exists
dnl AC_HAVE_DECL(var, includes)
AC_DEFUN(AC_HAVE_DECL,
[
 AC_CACHE_CHECK([for $1 declaration],ac_cv_have_$1_decl,[
    AC_TRY_COMPILE([$2],[int i = (int)$1],
        ac_cv_have_$1_decl=yes,ac_cv_have_$1_decl=no)])
 if test x"$ac_cv_have_$1_decl" = x"yes"; then
    AC_DEFINE([HAVE_]translit([$1], [a-z], [A-Z])[_DECL],1,[Whether $1() is available])
 fi
])


dnl check for a function in a library, but don't
dnl keep adding the same library to the LIBS variable.
dnl AC_LIBTESTFUNC(lib,func)
AC_DEFUN(AC_LIBTESTFUNC,
[case "$LIBS" in
  *-l$1*) AC_CHECK_FUNCS($2) ;;
  *) AC_CHECK_LIB($1, $2) 
     AC_CHECK_FUNCS($2)
  ;;
  esac
])

dnl Define an AC_DEFINE with ifndef guard.
dnl AC_N_DEFINE(VARIABLE [, VALUE])
define(AC_N_DEFINE,
[cat >> confdefs.h <<\EOF
[#ifndef] $1
[#define] $1 ifelse($#, 2, [$2], $#, 3, [$2], 1)
[#endif]
EOF
])

dnl Add an #include
dnl AC_ADD_INCLUDE(VARIABLE)
define(AC_ADD_INCLUDE,
[cat >> confdefs.h <<\EOF
[#include] $1
EOF
])

dnl Copied from libtool.m4
AC_DEFUN(AC_PROG_LD_GNU,
[AC_CACHE_CHECK([if the linker ($LD) is GNU ld], ac_cv_prog_gnu_ld,
[# I'd rather use --version here, but apparently some GNU ld's only accept -v.
if $LD -v 2>&1 </dev/null | egrep '(GNU|with BFD)' 1>&5; then
  ac_cv_prog_gnu_ld=yes
else
  ac_cv_prog_gnu_ld=no
fi])
])

dnl Removes -I/usr/include/? from given variable
AC_DEFUN(CFLAGS_REMOVE_USR_INCLUDE,[
  ac_new_flags=""
  for i in [$]$1; do
    case [$]i in
    -I/usr/include|-I/usr/include/) ;;
    *) ac_new_flags="[$]ac_new_flags [$]i" ;;
    esac
  done
  $1=[$]ac_new_flags
])
    
dnl Removes -L/usr/lib/? from given variable
AC_DEFUN(LIB_REMOVE_USR_LIB,[
  ac_new_flags=""
  for i in [$]$1; do
    case [$]i in
    -L/usr/lib|-L/usr/lib/) ;;
    *) ac_new_flags="[$]ac_new_flags [$]i" ;;
    esac
  done
  $1=[$]ac_new_flags
])

dnl AC_ENABLE_SHARED - implement the --enable-shared flag
dnl Usage: AC_ENABLE_SHARED[(DEFAULT)]
dnl   Where DEFAULT is either `yes' or `no'.  If omitted, it defaults to
dnl   `yes'.
AC_DEFUN([AC_ENABLE_SHARED],
[define([AC_ENABLE_SHARED_DEFAULT], ifelse($1, no, no, yes))dnl
AC_ARG_ENABLE(shared,
changequote(<<, >>)dnl
<<  --enable-shared[=PKGS]    build shared libraries [default=>>AC_ENABLE_SHARED_DEFAULT],
changequote([, ])dnl
[p=${PACKAGE-default}
case $enableval in
yes) enable_shared=yes ;;
no) enable_shared=no ;;
*)
  enable_shared=no
  # Look at the argument we got.  We use all the common list separators.
  IFS="${IFS=   }"; ac_save_ifs="$IFS"; IFS="${IFS}:,"
  for pkg in $enableval; do
    if test "X$pkg" = "X$p"; then
      enable_shared=yes
    fi

  done
  IFS="$ac_save_ifs"
  ;;
esac],
enable_shared=AC_ENABLE_SHARED_DEFAULT)dnl
])

dnl AC_ENABLE_STATIC - implement the --enable-static flag
dnl Usage: AC_ENABLE_STATIC[(DEFAULT)]
dnl   Where DEFAULT is either `yes' or `no'.  If omitted, it defaults to
dnl   `yes'.
AC_DEFUN([AC_ENABLE_STATIC],
[define([AC_ENABLE_STATIC_DEFAULT], ifelse($1, no, no, yes))dnl
AC_ARG_ENABLE(static,
changequote(<<, >>)dnl
<<  --enable-static[=PKGS]    build static libraries [default=>>AC_ENABLE_STATIC_DEFAULT],
changequote([, ])dnl
[p=${PACKAGE-default}
case $enableval in
yes) enable_static=yes ;;
no) enable_static=no ;;
*)
  enable_static=no
  # Look at the argument we got.  We use all the common list separators.
  IFS="${IFS=   }"; ac_save_ifs="$IFS"; IFS="${IFS}:,"
  for pkg in $enableval; do
    if test "X$pkg" = "X$p"; then
      enable_static=yes
    fi
  done
  IFS="$ac_save_ifs"
  ;;
esac],
enable_static=AC_ENABLE_STATIC_DEFAULT)dnl
])

dnl AC_DISABLE_STATIC - set the default static flag to --disable-static
AC_DEFUN([AC_DISABLE_STATIC],
[AC_BEFORE([$0],[AC_LIBTOOL_SETUP])dnl
AC_ENABLE_STATIC(no)])

dnl AC_TRY_RUN_STRICT(PROGRAM,CFLAGS,CPPFLAGS,LDFLAGS,
dnl		[ACTION-IF-TRUE],[ACTION-IF-FALSE],
dnl		[ACTION-IF-CROSS-COMPILING = RUNTIME-ERROR])
AC_DEFUN( [AC_TRY_RUN_STRICT],
[
	old_CFLAGS="$CFLAGS";
	CFLAGS="$2";
	export CFLAGS;
	old_CPPFLAGS="$CPPFLAGS";
	CPPFLAGS="$3";
	export CPPFLAGS;
	old_LDFLAGS="$LDFLAGS";
	LDFLAGS="$4";
	export LDFLAGS;
	AC_TRY_RUN([$1],[$5],[$6],[$7]);
	CFLAGS="$old_CFLAGS";
	old_CFLAGS="";
	export CFLAGS;
	CPPFLAGS="$old_CPPFLAGS";
	old_CPPFLAGS="";
	export CPPFLAGS;
	LDFLAGS="$old_LDFLAGS";
	old_LDFLAGS="";
	export LDFLAGS;
])

dnl AC_GET_MAKEFILE_VAR(FILE,OPTION,VARPREFIX)
AC_DEFUN( [AC_GET_MAKEFILE_VAR],
[
	$3$2=$(grep '^$2=' $1|cut -d '=' -f2-)
	if test -z "$[$3$2]"; then
		$3$2=$(grep '^$2 =' $1|cut -d '=' -f2-)
	fi
	AC_SUBST($3$2)
])

