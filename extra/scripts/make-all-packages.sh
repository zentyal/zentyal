#!/bin/sh

for i in libebox `ls client` ; do
	ebox-package $i
    sleep 20
done

