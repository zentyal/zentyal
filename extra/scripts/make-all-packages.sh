#!/bin/sh

REVISION=`svn info|grep Revision|cut -d: -f2`

for i in libebox `ls client` ; do 
	ebox-package $i hardy trunk $REVISION
done


sudo cp debs-ppa/* /var/www/ebox/
