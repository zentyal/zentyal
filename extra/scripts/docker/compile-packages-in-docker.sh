#!/bin/bash
set -e

ZENTYAL_FOLDER=$1
USER_FOLDER=$HOME
CONTAINER_NAME="zentyal30"

docker build -t $CONTAINER_NAME $ZENTYAL_FOLDER/extra/scripts/docker/.

echo " == COMPILE PACKAGES == "
sudo docker run -w /zentyal-repo/main -v $ZENTYAL_FOLDER:/zentyal-repo:rw -v $USER_FOLDER/.gnupg://.gnupg:rw --rm $CONTAINER_NAME /zentyal-repo/extra/scripts/zentyal-ppa-build.sh $2
