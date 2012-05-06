#!/bin/bash
set -e
inputfile=$1
outputfile="${inputfile%.*}.TaB.mkv"
idlist=(`mediainfo --Inform="Audio;%ID% " "$1"` )

width=$(mediainfo --Inform="Video;%Width%" "$1")
height=$(mediainfo --Inform="Video;%Height%" "$1")
sar=$(mediainfo --Inform="Video;%PixelAspectRatio%" "$1")
vcodec=`mediainfo --Inform="Video;%Format%" "$1"` 
halfwidth=$[width/2]
halfheight=$[height/2]
PATH=~/Documents/src/ffmpeg:$PATH
vcodecsettings=" -c:v libx264 -x264opts crf=18.0:level=4.1:vbv-bufsize=65200:vbv-maxrate=65200"
vfiltersettings="[in] scale=in_w:in_h/2 , setsar=$sar , split [scaled], crop=in_w/2:in_h:0:0 , pad=in_w:540+in_h:0:0:black , [right] overlay=0:540 [out] ; [scaled] crop=in_w/2:in_h:in_w/2:0 [right]" 

ffmpeg -i "$inputfile" -vf "$vfiltersettings" $vcodecsettings -threads:0 8 -c:a copy -c:s copy -map 0  "$outputfile"
# http://matroska.org/technical/specs/index.html
# Stereo-3D video mode (0: mono, 1: side by side (left eye is first), 2: top-bottom (right eye is first), 3: top-bottom (left eye is first), 4: checkboard (right is first), 5: checkboard (left is first), 6: row interleaved (right is first), 7: row interleaved (left is first), 8: column interleaved (right is first), 9: column interleaved (left is first), 10: anaglyph (cyan/red), 11: side by side (right eye is first), 12: anaglyph (green/magenta), 13 both eyes laced in one Block (left eye is first), 14 both eyes laced in one Block (right eye is first)) . There are some more details on 3D support in the Specification Notes.
mkvpropedit -e track:1 -s stereo-mode=3 "$outputfile"

