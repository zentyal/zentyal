#!/bin/bash

for dir in main extras
do
	echo -n > ${dir}_WITH_VERSIONS
	echo -n > ${dir}_WITHOUT_VERSIONS
	echo -n > REMOVE_${dir}

	for i in `find $dir -name "*.deb"`
	do
		NAME=`echo $i | sed 's/.*\///g' | cut -d'_' -f1`
		VERSION=`dpkg-deb --info $i | grep ^" Version:" | cut -d' ' -f3`
		echo "$NAME $VERSION" >> ${dir}_WITH_VERSIONS
		echo $NAME >> ${dir}_WITHOUT_VERSIONS
	done
done

cat main_WITHOUT_VERSIONS extras_WITHOUT_VERSIONS | sort | uniq -c | cut -c7- | grep -v ^1 | cut -d' ' -f2 > DUPLICATED_PACKAGES

for i in `cat DUPLICATED_PACKAGES`
do
	MAIN_VERSION=`grep $i main_WITH_VERSIONS | cut -d' ' -f2| head -1`
	EXTRA_VERSION=`grep $i extras_WITH_VERSIONS | cut -d' ' -f2 | head -1`
	# FIXME: Probably there is a bug here (false positive with samba)
	if [ $EXTRA_VERSION \> $MAIN_VERSION ]
	then
		echo "$i: extras version newer than main one"
	else
		echo $i >> REMOVE_extras
	fi
done

for dir in main extras
do
	rm ${dir}_WITH_VERSIONS
	rm ${dir}_WITHOUT_VERSIONS
done
rm DUPLICATED_PACKAGES
