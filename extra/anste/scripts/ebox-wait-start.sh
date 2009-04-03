#!/bin/bash

# Wait a maximum of ~60 seconds for apache start
for i in `seq 1 60`
do
    rm index.html
    wget http://localhost:1666
    if [ -f index.html ]
    then
        rm index.html
        exit 0
    else
        sleep 1 
    fi
done
exit 1
