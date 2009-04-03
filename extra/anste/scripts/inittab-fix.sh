#!/bin/sh

# Temporary workaround
#sed -i 's/tty1/console/' /etc/inittab

cd /dev

./MAKEDEV tty1 tty2 tty3
