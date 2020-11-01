#!/bin/bash

#################################
#            Config             #
#################################

# This script is supported by the tools youtube-dl, ffmpeg and jq. All of them need to be installed before usage of this script.

#Search this paths
PATHS=( "/path/to/movies1" "/path/to/movies2" )

#Your TheMovieDB API
API=<your API string here>

#Language Code
LANGUAGE=de #en

#Force redownload
OVERWRITE=false

#Custom path to store the log files. Uncomment this line and change the path. By default the working directory is going to be used.
#LOGPATH="/path/to/logs"



#################################

#Functions
downloadTrailer(){
####Using the Youtbe-dl-server in a container works but the script stops after the first actions is complete.
#        DL=$(docker run --name youtube-dl-temp -i --rm -v /your/volume/mount1:/your/volume/mount1 -v /your/volume/mount2:/your/volume/mount2  --user 1000:1000 kmb32123/youtube-dl-server \
#             youtube-dl -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" "https://www.youtube.com/watch?v=$ID" -o "$DIR/$OUTFILENAME-trailer.%(ext)s" --restrict-filenames --no-continue)
        DL=$(/usr/bin/python3 /usr/local/bin/youtube-dl -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"  "https://www.youtube.com/watch?v=$ID" \
        -o "$DIR/$OUTFILENAME-trailer.%(ext)s" --restrict-filenames --no-continue)
	    log "$DL"

	if [ -z "$(echo "$DL" | grep "100.0%")" ]; then
		missing ""
		missing "Error: Downloading failed - $FILENAME - $DIR - TheMovideDB: https://www.themoviedb.org/movie/$TMDBID - YouTube: https://www.youtube.com/watch?v=$ID"
		missing "------------------"
		missing "$DL"
		missing "------------------"
		missing ""
	fi
}

log(){
        echo "$1" |& tee -a "$LOGPATH/trailerdl.log"
}

missing(){
        echo "$1" |& tee -a "$LOGPATH/trailerdl-error.log" &>/dev/null
}

#################################

#Delete old logs
rm "$LOGPATH/trailerdl.log" &>/dev/null
rm "$LOGPATH/trailerdl-error.log" &>/dev/null

#Use manually provided language code (optional)
if [ "$1" = "force" ]; then
	OVERWRITE=true
elif ! [ -z "$1" ]; then
        LANGUAGE="$1"
fi

if [ "$2" = "force" ]; then
        OVERWRITE=true
fi

if [ -z "$LOGPATH" ]; then
        LOGPATH=$(pwd)
fi


#Walk defined paths and search for movies without existing local trailer
for i in "${PATHS[@]}"
do

	find "$i" -mindepth 1 -maxdepth 2 -name '*.nfo*' -printf "%h\n" | sort -u | while read DIR
        do
	        #FILENAME=$(ls "$DIR" | egrep '\.nfo$' | awk 'NR==1' | sed s/".nfo"//g)
                FILENAME=$(ls -1 "$DIR" | gawk 'match($0,/^(.*)\.nfo$/,a) {print a[1]; exit}')
                
                if [ -f "$DIR"/movie.nfo ]
                then
                        OUTFILENAME=$(awk -F "[><]" '/<title>/{print $3}' "$DIR"/movie.nfo | sed s/"\/"/+/g)
                else
                        OUTFILENAME=$(awk -F "[><]" '/<title>/{print $3}' "$DIR/$FILENAME.nfo" | sed s/"\/"/+/g)
                fi

                if ! [ -f "$DIR/$OUTFILENAME-trailer.mp4" ] || [ $OVERWRITE = "true" ]; then
		#if ! [ -f "$DIR"/*trailer* ] || [ $OVERWRITE = "true" ]; #errors out if more than one file with name containing trailer

                        #Get TheMovieDB ID from NFO
                        TMDBID=$(awk -F "[><]" '/tmdbid/{print $3}' "$DIR/$FILENAME.nfo" | awk -F'[ ]' '{print $1}')

                        log ""
                        log "Movie Path: $DIR"
                        log "Processing file: $FILENAME.nfo"

                        if ! [ -z "$TMDBID" ]; then

                                log "TheMovieDB: https://www.themoviedb.org/movie/$TMDBID"

                                #Get trailer YouTube ID from themoviedb.org
                                JSON=($(curl -s "http://api.themoviedb.org/3/movie/$TMDBID/videos?api_key=$API&language=$LANGUAGE" | jq '.results | sort_by(-.size)' | jq -r '.[] | select(.type=="Trailer") | .key'))
                                ID="${JSON[0]}"

                                if ! [ -z "$ID" ]; then
                                		#Start download
                                        log "YouTube: https://www.youtube.com/watch?v=$ID"
                                        downloadTrailer

                                else
                                        log "YouTube: n/a"
                                        missing "Error: Missing YouTube ID - $FILENAME - $DIR - TheMovideDB: https://www.themoviedb.org/movie/$TMDBID"

                                fi

                        else
                        		log "TheMovieDB: n/a"
                                missing "Error: Missing TheMovieDB ID - $FILENAME - $DIR"
                        fi

                fi
        done
done
