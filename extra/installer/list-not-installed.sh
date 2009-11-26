#!/bin/sh

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
                    size=`du $pkgfile`
                    echo "$size $pkgfile"
                fi
            fi
          done
        cd ..
      done
    cd ..
  done
find -depth -type d -empty -exec echo {} \;
