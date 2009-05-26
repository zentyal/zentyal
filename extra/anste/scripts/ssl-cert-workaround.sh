#!/bin/sh

# create the directories if needed, so we cna use this in the pre-install
# WARNING!. this makes the direcory with wrong permissions and owneship so is not secure
mkdir -p /etc/ssl/private

touch /etc/ssl/private/ssl-cert-snakeoil.key
touch /etc/ssl/private/ssl-cert-snakeoil.key
