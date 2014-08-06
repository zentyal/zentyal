#!/bin/bash
set -e

ZENTYAL_FOLDER=$1
CONTAINER_NAME="zentyal/40"
shift

echo " == RUNNING UNIT TESTS == "
docker run -u="testUser" -v $ZENTYAL_FOLDER:/zentyal-repo:rw --rm $CONTAINER_NAME /zentyal-repo/extra/scripts/zentyal-unit-tests "$@"
