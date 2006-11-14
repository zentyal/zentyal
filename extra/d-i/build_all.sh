#!/bin/sh

# Script to build everything possible : sources and binaries for all archs

. CONF.sh

TMP_OUT=$OUT

for ARCH in i386 alpha arm hppa ia64 m68k mips mipsel powerpc s390 sparc #amd64
do
	export ARCH
	echo "Now we're going to build CD for $ARCH !"
	echo " ... cleaning"
	make distclean
	make ${CODENAME}_status
	echo " ... checking your mirror"
	if [ "$SKIPMIRRORCHECK" != "yes" ] ; then 
		make mirrorcheck
	else
		echo "WARNING: skipping mirrorcheck"
	fi

	if [ $? -gt 0 ]; then
		echo "ERROR: Your mirror has a problem, please correct it." >&2
		exit 1
	fi
	echo " ... selecting packages to include"
	if [ -e ${MIRROR}/dists/${CODENAME}/main/disks-${ARCH}/current/. ] ; then
		disks=`du -sm ${MIRROR}/dists/${CODENAME}/main/disks-${ARCH}/current/. | \
				awk '{print $1}'`
	else
		disks=0
	fi
	if [ -f $BASEDIR/tools/boot/$CODENAME/boot-$ARCH.calc ]; then
	    . $BASEDIR/tools/boot/$CODENAME/boot-$ARCH.calc
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
    make list COMPLETE=1 $SIZE_ARGS SRCSIZELIMIT=$FULL_SIZE
	echo " ... building the images"
	if [ "$ARCH" = "i386" ]; then
		export OUT="$TMP_OUT/$ARCH"; mkdir -p $OUT
		make bin-official_images
		echo Generating MD5Sums of the images
		make imagesums
		echo Generating list files for images
		make pi-makelist

		export OUT="$TMP_OUT/src"; mkdir -p $OUT
		make src-official_images
		echo Generating MD5Sums of the images
		make imagesums
		echo Generating list files for images
		make pi-makelist
	else
		export OUT=$TMP_OUT/$ARCH; mkdir -p $OUT
		make bin-official_images
		if [ $? -gt 0 ]; then
			echo "ERROR WHILE BUILDING OFFICIAL IMAGES !!" >&2
			if [ "$ATTEMPT_FALLBACK" = "yes" ]; then
				echo "I'll try to build a simple (non-bootable) CD" >&2
				make clean
				make installtools
				make bin-images
			else
				exit 1
			fi
		fi
		echo Generating MD5Sums of the images
		make imagesums
		echo Generating list files for images
		make pi-makelist
	fi
	echo "--------------- `date` ---------------"
done
