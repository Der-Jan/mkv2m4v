#!/bin/bash
set -e
mp4tmp=.
fifofile=$mp4tmp/tmp_fifo.m4v
## tmpvideo=$mp4tmp/tmp.h264
partfileduration=600
rm -f "$fifofile"
## rm -f "$tmpvideo"
inputfile=$1
format=`mediainfo --Inform="General;%FileExtension%" "$1"` 

muxfile=0
demuxdir=$mp4tmp/m2mtrack
[ -d $demuxdir ] && rm -rf $demuxdir
mkdir $demuxdir
chapterfile=$demuxdir/tmp.chapters
idcorrect=0
if [ "$format" == "mkv" ]; then
	idcorrect=1
	if mkvextract chapters -s "$inputfile" >$chapterfile && [ -n "`cat $chapterfile`" ]; then 
# MP4Box doesnt like chapters coming from ffmpeg -> demux
		muxfile=1
		sleep 1
	else
		rm $chapterfile
	fi
	mkvsubs=$( mediainfo --Inform="Text;%ID%:$demuxdir/%ID%%Language/String3%.srt " "$inputfile" )
	if [ -n "$mkvsubs" ]; then
		mkvextract tracks "$inputfile" $mkvsubs
		addmp4file=( ${addmp4file[@]-} $( mediainfo --Inform="Text;-add $demuxdir/%ID%%Language/String3%.srt:lang=%Language/String3%:group=2 " "$inputfile" ) )
	fi
# check broken matroska - has to be handled via mkvextract
	if ffmpeg -i "$inputfile" -t 3 -c:v copy -an -sn "$fifofile"; then
		rm "$fifofile"
	else
		rm "$fifofile"
		muxfile=1
	fi
else if [ "$format" == "mp4" ]; then
	idcorrect=1
fi
fi
[ $format == "wmv" ] && idcorrect=1

outputfile="${inputfile%.*}.m4v"
[ -z "$2" ] || outputfile="$2/`basename \"${outputfile}\"`"
subtitlefile="${inputfile%.*}.srt"
if [ -f "$subtitlefile" ]; then
	addmp4file=( ${addmp4file[@]-} -add "$subtitlefile":lang=eng:group=2 )
fi
declare -a audiolist
audiolist=(`mediainfo --Inform="Audio;%Format%:" "$1"| awk '{ gsub(" ","_");gsub(":"," "); print; }' ` )
declare -a channelslist 
channelslist=(`mediainfo --Inform="Audio;%Channels% " "$1"`) 
langlist=(`mediainfo --Inform="Audio;%Language/String3% " "$1"` )
idlist=(`mediainfo --Inform="Audio;%ID% " "$1"` )

vcodec=`mediainfo --Inform="Video;%Format%" "$1"` 
vid=(`mediainfo --Inform="Video;%ID% " "$1"` )
if [ "$vcodec" == "AVC" ]; then
	vcodecsettings="-c:v copy"
	mkvextract+="$vid:$demuxdir/$vid.h264 "
	mp4mux+="-add $demuxdir/$vid.h264 "
else
	vcodecsettings=" -c:v libx264 -x264opts crf=18.0:level=4.1:vbv-bufsize=65200:vbv-maxrate=62500"
	mkvextract+="$vid:$demuxdir/$vid.xvid "
	mp4mux+="-add $demuxdir/$vid.xvid "
fi
if [ -f "$outputfile" ]; then
	echo "Deleting existing destination file $outputfile"
	rm "$outputfile"
fi
# mkfifo "$fifofile"
alternategroups=""
mapping="-map 0:$[`mediainfo --Inform=\"Video;%ID%\" \"$inputfile\"`-$idcorrect] "
declare -a audiochannels
counter=0
trackCounter=2
for audio in "${audiolist[@]}"; do
echo New track $audio
channels=${channelslist[$counter]}
lang=${langlist[$counter]}
trackid=$[${idlist[$counter]}-$idcorrect]
extractid=${idlist[$counter]}
[ -z "$trackid" ] && trackid=$[counter+1]
[ -z "$lang" ] && lang="eng"
if [ -z "$firstaudiochannel" ]; then
	firstaudiochannel="x"
else
	addmp4opt+="mp4track --track-id ${trackCounter} --enabled false $fifofile;"
fi
mapping+="-map 0:$trackid "
addmp4opt+="mp4track --track-id ${trackCounter} --altgroup 1 $fifofile; mp4track --track-id ${trackCounter} --udtaname Stereo_$lang $fifofile;mp4track --track-id ${trackCounter} --language $lang $fifofile;"
if [ "$audio" == "AC-3" ] ; then
	audiochannels=( ${audiochannels[@]-} -sample_fmt:a:$[trackCounter-2] flt -c:a:$[trackCounter-2] aac -ac:a:$[trackCounter-2] 2 -ab:a:$[trackCounter-2] 128k )
	((trackCounter++))
	audiochannels=( ${audiochannels[@]-} -c:a:$[trackCounter-2] copy )
	addmp4opt+="mp4track --track-id ${trackCounter} --altgroup 1 $fifofile; mp4track --track-id ${trackCounter} --enabled false $fifofile; mp4track --track-id ${trackCounter} --udtaname Surround_$lang $fifofile;mp4track --track-id ${trackCounter} --language $lang $fifofile;"
	mapping+="-map 0:$trackid "
	mkvextract+="$extractid:$demuxdir/$[counter+2].ac3 "
	mp4mux+="-add $demuxdir/$[counter+2].ac3 "
	((trackCounter++))
elif [ "$audio" == "DTS" ] ; then
	audiochannels=( ${audiochannels[@]-} -sample_fmt:a:$[trackCounter-2] flt -c:a:$[trackCounter-2] aac -ac:a:$[trackCounter-2] 2 -ab:a:$[trackCounter-2] 128k )
	((trackCounter++))
	addmp4opt+="mp4track --track-id ${trackCounter} --altgroup 1 $fifofile; mp4track --track-id ${trackCounter} --enabled false $fifofile;  mp4track --track-id ${trackCounter} --udtaname Surround_$lang $fifofile;mp4track --track-id ${trackCounter} --language $lang $fifofile;"
	mapping+="-map 0:$trackid "
	if [ $muxfile -gt 0 ]; then
		audiochannels=( ${audiochannels[@]-} -c:a:$[trackCounter-2] copy )
	else
		audiochannels=( ${audiochannels[@]-} -c:a:$[trackCounter-2] ac3 -ac:a:$[trackCounter-2] $channels -ab:a:$[trackCounter-2] 640k )
	fi
	mkvextract+="$extractid:$demuxdir/$[counter+2].dts "
	dtsconvert+="ffmpeg -i $demuxdir/$[counter+2].dts -c:a ac3 -ac $channels -ab 640k $demuxdir/$[counter+2].ac3; "
	mp4mux+="-add $demuxdir/$[counter+2].ac3 "
	((trackCounter++))
elif [ "$audio" == "AAC" ] ; then
	audiochannels=( ${audiochannels[@]-} -c:a:$[trackCounter-2] copy )
	mkvextract+="$extractid:$demuxdir/$[counter+2].aac "
	mp4mux+="-add $demuxdir/$[counter+2].aac "
	((trackCounter++))
else
	audiochannels=( ${audiochannels[@]-} -sample_fmt:a:$[trackCounter-2] flt -c:a:$[trackCounter-2] aac -ac:a:$[trackCounter-2] $channels -ab:a:$[trackCounter-2] 128k )
	mkvextract+="$extractid:$demuxdir/$[counter+2].mp3 "
	mp4mux+="-add $demuxdir/$[counter+2].mp3 "
	((trackCounter++))
fi
((counter++))
done

if [ $muxfile -gt 0 ]; then
	mkvextract tracks "$inputfile" $mkvextract
	[ -z "$dtsconvert" ] || eval $dtsconvert
	for i in $demuxdir/*; do
		touch -r "$inputfile" $i
	done
	inputfile=$demuxdir/mkvtemp.mp4
	MP4Box -tmp $mp4tmp $inputfile $mp4mux
fi

# FIXME mapping for m2ts
[ $format == "m2ts" ] && mapping=""
ffmpeg -i "$inputfile" $mapping $vcodecsettings -threads 8 -strict -2 -sn ${audiochannels[@]} "$fifofile" 
[ -z "$addmp4opt" ] || eval $addmp4opt
[ $(mediainfo --Inform="Video;%Width%" "$fifofile") -lt 769 ] || mp4tags -hdvideo 1 "$fifofile" 
mp4file --optimize "$fifofile"
[ -f "$chapterfile" ] && addmp4file=( ${addmp4file[@]-} -chap $chapterfile )
[ -z "${addmp4file[0]}" ] || MP4Box -tmp $mp4tmp "$fifofile" "${addmp4file[@]}" 
mv "$fifofile" "$outputfile"
touch -r "$inputfile" "$outputfile"
rm -r $demuxdir
