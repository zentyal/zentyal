#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

APT_OPTIONS='-o Dpkg::Options::=--force-confnew -o Dpkg::Options::=--force-confdef';

apt-get install -f -y --force-yes $APT_OPTIONS
