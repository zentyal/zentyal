#!/bin/sh

po-am.generator > po/Makefile.am
mkdir -p config
aclocal -I m4
autoconf
automake --add-missing
./configure $*
