#!/bin/bash
set -e

ZENTYAL_FOLDER=$1
USER_FOLDER=$HOME
CONTAINER_NAME="zentyal/41"

echo " == BUILDING DOCKER IMAGE == "
$ZENTYAL_FOLDER/extra/scripts/docker/build-docker-image.sh $ZENTYAL_FOLDER $CONTAINER_NAME

echo " == COMPILE PACKAGES == "
sudo docker run -w /zentyal-repo/main -v $ZENTYAL_FOLDER:/zentyal-repo:rw -v $USER_FOLDER/.gnupg:/root/.gnupg:rw --rm $CONTAINER_NAME /zentyal-repo/extra/scripts/zentyal-ppa-build.sh $2
