#!/bin/bash
set -e

ZENTYAL_FOLDER=$1
CONTAINER_NAME=$2

cp $ZENTYAL_FOLDER/extra/scripts/docker/Dockerfile $ZENTYAL_FOLDER/.

docker build -t $CONTAINER_NAME $ZENTYAL_FOLDER/.

rm -rf $ZENTYAL_FOLDER/Dockerfile 
