#!/bin/bash

DEBS_PPA=../../../main/debs-ppa

for dir in extras-i386 extras-amd64
do
    for i in `ls $DEBS_PPA/*.deb | cut -d_ -f1 |cut -d/ -f6`
    do
        rm $dir/${i}_*.deb
        cp $DEBS_PPA/${i}_*.deb $dir/
    done
done
