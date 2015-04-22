#!/bin/bash
set -e

ZENTYAL_FOLDER=$1
CONTAINER_NAME="zentyal/41"

echo " == BUILDING DOCKER IMAGE == "
$ZENTYAL_FOLDER/extra/scripts/docker/build-docker-image.sh $ZENTYAL_FOLDER $CONTAINER_NAME


echo " == RUNNING SYNTAX CHECK == "
sudo rm -rf $ZENTYAL_FOLDER/test
docker run -v $ZENTYAL_FOLDER:/zentyal-repo:rw --rm $CONTAINER_NAME /zentyal-repo/extra/scripts/zentyal-syntax-check --update --path=/zentyal-repo --release=precise
sudo rm -rf $ZENTYAL_FOLDER/test


echo " == RUNNING UNIT TESTS == "
docker run -u="testUser" -v $ZENTYAL_FOLDER:/zentyal-repo:rw --rm $CONTAINER_NAME /zentyal-repo/extra/scripts/zentyal-unit-tests -js ALL > $ZENTYAL_FOLDER/test_results.xml

