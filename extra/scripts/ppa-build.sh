#!/bin/bash

# Change this with your PPA key ID
KEY_ID="19AD31B8"

dpkg-buildpackage -k$KEY_ID -S -sa
