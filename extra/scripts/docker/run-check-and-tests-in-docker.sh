#!/bin/bash
set -e

ZENTYAL_FOLDER=$1
CONTAINER_NAME="zentyal30"

docker build -t $CONTAINER_NAME $ZENTYAL_FOLDER/extra/scripts/docker/.

rm -rf $ZENTYAL_FOLDER/test

echo " == RUNNING SYNTAX CHECK == "
docker run -v $ZENTYAL_FOLDER:/zentyal-repo:rw --rm $CONTAINER_NAME /zentyal-repo/extra/scripts/zentyal-syntax-check --update --path=/zentyal-repo --release=precise

echo " == RUNNING UNIT TESTS == "
docker run -u="testUser" -v $ZENTYAL_FOLDER:/zentyal-repo:rw --rm $CONTAINER_NAME /zentyal-repo/extra/scripts/zentyal-unit-tests -js common > $ZENTYAL_FOLDER/test_results.xml

