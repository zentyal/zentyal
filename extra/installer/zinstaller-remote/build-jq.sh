#!/bin/bash

mkdir tmp
cd tmp
sudo apt-get install libonig-dev
wget http://stedolan.github.io/jq/download/source/jq-1.4.tar.gz
tar xzf jq-1.4.tar.gz
cd jq-1.4
./configure
make
mv jq ../../
cd ../..
rm -rf tmp

