#!/bin/bash

# script to generate alaw, ulaw and gsm files from mp3 for Asterisk music on hold
# these files should be dropped in /var/lib/asterisk/moh/

for f in *.mp3
do
    FILE=$(basename $f .mp3) 
    # generate alaw & ulaw
    ffmpeg -i ${FILE}.mp3 -ar 8000 -ac 1 -ab 64 ${FILE}.wav -ar 8000 -ac 1 -ab 64 -f mulaw ${FILE}.pcm -map 0:0 -map 0:0
    # generate gsm
    sox $FILE.wav -t gsm -r 8000 -c 1 $FILE.gsm
done
