#!/bin/bash

# This script updates the various packaging files
# to make them compatible with a 'single arch' debian system (squeeze, lucid)

# remove '/*/' from the library paths
for file in *install; do
  sed -i".ma" -e 's/lib\/\*\//lib\//'  $file
done

# remove multiarch related statements in control file
sed -i".ma" -e '/Pre-Depends:/d; /Multi-Arch: same/d;' control


