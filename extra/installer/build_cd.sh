#!/bin/bash

. ./build_cd.conf

test -d $CD_BUILD_DIR || (print "No CD build directory found"; exit 1);
test -d $EXTRAS_DIR   || (print "No extra packages directory found"; exit 1);

test -d $CD_BUILD_DIR/isolinux || (print "No isolinux directory found in $CD_BUILD_DIR. Are you sure you had copied correctly the CD data?"; exit 1);
test -d $CD_BUILD_DIR/.disk || (print "No .disk directory found in $CD_BUILD_DIR. Are you sure you had copied correctly the CD data?"; exit 1);


pushd $SCRIPTS_DIR

./genLocalesFile.pl $DATA_DIR || (print "Autogeneration of locales files failed. Make usre you have a updated version of EBox::Gettext in your perl path." && exit 1)


CD_SCRIPTS='./customUbuntuKeyring.sh ./configureAptFtpArchive.sh ./addExtrasToPool.sh ./updateMd5sum.sh ./put-ebox-stuff.sh ./mkisofs.sh'
for SCRIPT in $CD_SCRIPTS; do
    $SCRIPT || (print "$SCRIPT failed" && exit 1)
done

popd


echo "Installer image created: $ISO_IMAGE"

# XXX remove this step with new apt-key package
# remove release signature
#find $BUILD_DIR -name Release.gpg | xargs -n 1 rm -vf