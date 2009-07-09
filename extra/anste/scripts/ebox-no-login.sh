#!/bin/sh

# Remove login screen (no auth required)

APACHE_TEMPLATE=/usr/share/ebox/stubs/apache.mas

sed -i 's/AuthType EBox::Auth//g' $APACHE_TEMPLATE
sed -i 's/AuthName EBox//g' $APACHE_TEMPLATE
sed -i 's/PerlAuthenHandler EBox::Auth->authenticate//g' $APACHE_TEMPLATE
sed -i 's/PerlAuthzHandler  EBox::Auth->authorize//g' $APACHE_TEMPLATE
sed -i 's/require valid-user//g' $APACHE_TEMPLATE
