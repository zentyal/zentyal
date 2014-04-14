#!/bin/bash
set -e

ZENTYAL_FOLDER=$1
CONTAINER_NAME="zentyal32"

docker build -t $CONTAINER_NAME $ZENTYAL_FOLDER/extra/scripts/.

rm -rf $ZENTYAL_FOLDER/test

docker run -v $ZENTYAL_FOLDER:/zentyal-repo:rw $CONTAINER_NAME /zentyal-repo/extra/scripts/zentyal-syntax-check --update --path=/zentyal-repo --release=precise

docker run -u="testUser" -v $ZENTYAL_FOLDER:/zentyal-repo:rw $CONTAINER_NAME /zentyal-repo/extra/scripts/zentyal-unit-tests -js common > $ZENTYAL_FOLDER/test_results.xml

