#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

APT_OPTIONS='-o Dpkg::Options::=--force-confnew -o Dpkg::Options::=--force-confdef';

LOG=/var/log/anste-force-install-`date +%y%m%d%H%M%S`.log

apt-get install -f -y --force-yes $APT_OPTIONS &> $LOG 
