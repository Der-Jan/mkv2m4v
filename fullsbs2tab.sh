#!/bin/bash
set -e
inputfile=$1
outputfile="${inputfile%.*}.TaB.mkv"
idlist=(`mediainfo --Inform="Audio;%ID% " "$1"` )

width=$(mediainfo --Inform="Video;%Width%" "$1")
height=$(mediainfo --Inform="Video;%Height%" "$1")
vcodec=`mediainfo --Inform="Video;%Format%" "$1"` 
halfwidth=$[width/2]
halfheight=$[height/2]

vcodecsettings=" -c:v libx264 -x264opts crf=18.0:level=4.1:vbv-bufsize=65200:vbv-maxrate=62500"

ffmpeg -i "$inputfile" -y -threads 0 -vf "[in] scale=in_w:in_h/2 , split [scaled], crop=in_w/2:in_h:0:0 , pad=in_w:1080:0:270-in_h/2:black , [right] overlay=0:810-overlay_h/2 [out] ; [scaled] crop=in_w/2:in_h:in_w/2:0 [right]" $vcodecsettings -an -sn  "$outputfile" 
