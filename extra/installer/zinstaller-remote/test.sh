#!/bin/bash

sudo true

dpkg-buildpackage

echo PURGE | sudo debconf-communicate zinstaller-remote

sudo dpkg -i ../zinstaller-remote*deb
