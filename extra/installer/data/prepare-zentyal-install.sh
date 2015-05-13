#!/bin/bash

# Vagrant stuff
echo "vagrant ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vagrant && \
mkdir -p /home/vagrant/.ssh && \
chmod 0700 /home/vagrant/.ssh && \
wget --no-check-certificate  https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub -O /home/vagrant/.ssh/authorized_keys && \
chmod 0600 /home/vagrant/.ssh/authorized_keys && \
chown -R vagrant /home/vagrant/.ssh && \
echo "AuthorizedKeysFile %h/.ssh/authorized_keys" >> /etc/ssh/sshd_config

### CUSTOM_ACTION ###

sync

exit 0
