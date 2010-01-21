#!/bin/sh

PACKAGE_NAME=ebox-package-installer

echo "Updating ${PACKAGE_NAME}.pot file"
xgettext --default-domain $PACKAGE_NAME --directory ../ \
         --add-comments=TRANSLATORS: --language Perl -k__ -k__n -k__x -k__d \
         --flag=__:1:pass-perl-format --flag=__:1:pass-perl-brace-format \
         --copyright-holder='eBox Technologies S.L- 2010' \
         --msgid-bugs-address='info@ebox-technologies.com' \
         --from-code=utf-8 --package-name=$PACKAGE_NAME \
         --package-version=1.4 $PACKAGE_NAME

mv -f ${PACKAGE_NAME}.po ${PACKAGE_NAME}.pot

for locale in $(cat LINGUAS)
do
    if [ -e ${locale}.po ]; then
        echo -n "Updating $locale locale for the installer"
        msgmerge -U ${locale}.po ${PACKAGE_NAME}.pot
    else
        echo "Creating $locale locale for the installer"
        msginit --input=${PACKAGE_NAME} --locale=$locale --output=${locale}.po --no-translator
        sed -i -e 's/charset=.*\\/charset=UTF-8\\/' ${locale}.po
    fi
    
done