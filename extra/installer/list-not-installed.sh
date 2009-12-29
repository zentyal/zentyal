#!/bin/sh

# If we do a normal installation, without using LVM, cryptsetup or RAID, we should
# avoid deleting the following packages
MANDATORY_PACKAGES="
lvm
dmsetup
devmapper
crypt
mdadm
kpartx
multipath
lilo
xfs
jfs"

cd /cdrom/pool/main

for j in *
do
    cd $j
    for k in *
    do
        cd $k
        for l in *.deb
        do
            if [ $l != "*.deb" ]
            then
                n=$(dpkg -l $(echo $l | cut -f1 -d"_") 2> /dev/null| grep "^ii")
                if [ -z "$n" ]
                then
                    pkgfile=/cdrom/pool/main/$j/$k/$l
                    skip=0
                    for i in $MANDATORY_PACKAGES
                    do
                        if echo $pkgfile | grep -q $i
                        then
                            skip=1
                            break
                        fi
                    done
                    if [ $skip -eq 0 ]
                    then
                        #size=`du $pkgfile`
                        #echo "$size $pkgfile"
                        echo $pkgfile
                    fi
                fi
            fi
        done
        cd ..
    done
    cd ..
done
find -depth -type d -empty -exec echo {} \;
