#!/bin/sh -e

# Script to build one arch

if [ -z "$CF" ] ; then
    CF=CONF.sh
fi
. $CF

if [ -z "$COMPLETE" ] ; then
    export COMPLETE=1
fi

if [ -n "$1" ] ; then
    export ARCH=$1
fi

make distclean
make ${CODENAME}_status
if [ "$SKIPMIRRORCHECK" = "yes" ]; then
    echo " ... WARNING: skipping mirror check"
else
    echo " ... checking your mirror"
    make mirrorcheck
    if [ $? -gt 0 ]; then
	    echo "ERROR: Your mirror has a problem, please correct it." >&2
	    exit 1
    fi
fi
echo " ... selecting packages to include"
if [ -e ${MIRROR}/dists/${DI_CODENAME}/main/disks-${ARCH}/current/. ] ; then
	disks=`du -sm ${MIRROR}/dists/${DI_CODENAME}/main/disks-${ARCH}/current/. | \
        	awk '{print $1}'`
else
	disks=0
fi
if [ -f $BASEDIR/tools/boot/$DI_CODENAME/boot-$ARCH.calc ]; then
    . $BASEDIR/tools/boot/$DI_CODENAME/boot-$ARCH.calc
fi
SIZE_ARGS=''
for CD in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
	size=`eval echo '$'"BOOT_SIZE_${CD}"`
	[ "$size" = "" ] && size=0
	[ $CD = "1" ] && size=$(($size + $disks))
	mult=`eval echo '$'"SIZE_MULT_${CD}"`
	[ "$mult" = "" ] && mult=100
    FULL_SIZE=`echo "($DEFBINSIZE - $size) * 1024 * 1024" | bc`
	echo "INFO: Reserving $size MB on CD $CD for boot files.  SIZELIMIT=$FULL_SIZE."
    if [ $mult != 100 ]; then
        echo "  INFO: Reserving "$((100-$mult))"% of the CD for extra metadata"
        FULL_SIZE=`echo "$FULL_SIZE * $mult" / 100 | bc`
        echo "  INFO: SIZELIMIT now $FULL_SIZE."
    fi
	SIZE_ARGS="$SIZE_ARGS SIZELIMIT${CD}=$FULL_SIZE"
done

FULL_SIZE=`echo "($DEFSRCSIZE - $size) * 1024 * 1024" | bc`
make list $SIZE_ARGS SRCSIZELIMIT=$FULL_SIZE
echo " ... building the images"
if [ -z "$IMAGETARGET" ] ; then
    IMAGETARGET="official_images"
fi
make $IMAGETARGET

make imagesums
