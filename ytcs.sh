#!/bin/bash


##############################################################################
#
#  youtube-cli-subscriptions -- to scroll through and view youtube videos 
#  through RSS feeds and yt-dlp and mpv
#  
#  (c) Steven Saus 2025
#  Licensed under the MIT license
#
##############################################################################

### if file is first input, will parse the subscription file (and refresh cache files)
## if g - grouped output to rofi
## if c - chronological output to rofi
ROFI_THEME="sidebar_right"
SCRIPTDIR="$( cd "$(dirname "$0")" ; pwd -P )"

if [ -z "${XDG_DATA_HOME}" ];then
    export XDG_DATA_HOME="${HOME}/.local/share"
    export XDG_CONFIG_HOME="${HOME}/.config"
fi

CACHEDIR="${XDG_DATA_HOME}/youtube-cli-subcriptions"
if [ ! -d "${CACHEDIR}" ];then
    mkdir -p "${CACHEDIR}"
fi
LOUD=1
wget_bin=$(which wget)
mpv_bin=$(which mpv)
grep_bin=$(which grep)
ytube_bin=$(which youtube-dl)
dlp=$(which yt-dlp)
if [ "$dlp" != "" ];then
    ytube_bin="${dlp}"
fi

function loud() {
##############################################################################
# loud outputs on stderr 
##############################################################################    
    if [ $LOUD -eq 1 ];then
        echo "$@" 1>&2
    fi
}

display_help(){
##############################################################################
# Show the Help
##############################################################################    
    echo "###################################################################"
    echo "# --help - shows this"
    echo "# --import [/path/to/csv]: Import CSV of subscriptions"
    echo "# --refresh: refresh subscriptions"
    echo "# --subscription: browse by subscription"
    echo "# --subscription: browse by subscription"
    echo "# --grouped: choose grouped by subscription"
    echo "# --time: choose in chronological order"
    echo "###################################################################"
    exit
}

import_subscriptions() 
{
    if [ -z "$SUBSCRIPTIONFILE" ];then
        SUBSCRIPTIONFILE="$1"
    fi
    
    while read line; do
        id=$(echo "$line"|awk -F ',' '{print $1}')
        url=$(echo "$line"|awk -F ',' '{print $2}')
        name=$(echo "$line"|awk -F ',' '{print $3}')
        if [[ "$id" != "Channel Id" ]];then
            wget_string=$(printf "%s \"%s%s\" -O %s/%s" "${wget_bin}" "https://www.youtube.com/feeds/videos.xml?channel_id=" "${id}" "${CACHEDIR}" "${id}") 
            eval "${wget_string}"
        fi
    done < "$SUBSCRIPTIONFILE"
    exit
}

refresh_subscriptions() {
    for file in "$CACHEDIR"/*; do  
        id=$(grep -m 1 "<yt:channelId>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
        if [ -f "$file" ];then
            wget_string=$(printf "%s \"%s%s\" -O %s/%s" "${wget_bin}" "https://www.youtube.com/feeds/videos.xml?channel_id=" "$id" "$CACHEDIR" "$id") 
            eval "${wget_string}"
        fi
        id=""
    done
}

mark_age() {
    local two_weeks_ago four_weeks_ago line date_string line_ts
    two_weeks_ago=$(date -d '14 days ago' +%s)
    four_weeks_ago=$(date -d '28 days ago' +%s)

    while IFS= read -r line; do
        # Extract the ISO date from field 2 (trimmed)
        date_string=$(echo "$line" | awk -F '|' '{print $2}' | xargs)
        line_ts=$(date -d "$date_string" +%s 2>/dev/null)

        if [[ -z "$line_ts" ]]; then
            echo "$line"
            continue
        fi

        if (( line_ts < four_weeks_ago )); then
            echo "⌛ $line"
        elif (( line_ts < two_weeks_ago )); then
            echo "⏳ $line"
        else
            echo "$line"
        fi
    done
}

parse_subscriptions(){
    trap '' PIPE
    if [ "$1" = "g" ];then
        # this is per subscription, latest 5 
        shopt -s nullglob  # avoids looping if no match
        for file in "${CACHEDIR}"/*; do  
            [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
            ChanSubFile=""
            if [ -f "$file" ];then
                chantitle=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                chanid=$(grep -m 1 "<yt:channelId>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                thischanneltitle=$(printf "§ 📺 %s" "$chantitle")
                thischanneldata=$(sed -n '/<entry>/,$p' "$file" | grep -e "<yt:videoId>" -e "<title>" -e "<published>" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | sed 's/|//g'| sed 'N;N;s/\n/|/g' | sed 's/&quot;/‘/g' | sed 's/&amp;/and/g' | head -5 | awk -F '|' '{print $2 " | " $3 " |" $1}')
                allfiledata="$allfiledata\\n$thischanneltitle\\n$thischanneldata"
            else
                echo "Error in reading subscriptions list!"
            fi
        done
        if [ -f "${CACHEDIR}"/watched_files.txt ];then
            # Filter and prepend § Exit
            {
                echo "§ Exit"
                while IFS= read -r line; do
                    id="${line##*| }"  # Extract the string after the last "| "
                    command=$(printf "%s -c -- \"%s\" \"%s\"" "${grep_bin}" "${id}" "${CACHEDIR}/watched_files.txt")
                    count=$(eval "${command}")
                    if [ "$count" == "" ];then
                        count=0
                    fi
                    if [ $count -ge 1 ]; then
                        echo "👀 $line" | mark_age
                    else
                        echo "$line" | mark_age
                    fi
                done <<< "$(echo -e "$allfiledata")"
            }
        else
            { echo "§ Exit"; echo -e "$allfiledata"; }
        fi        
    else
        # This is chronological, all subscriptions
        shopt -s nullglob  # avoids looping if no match
        for file in "${CACHEDIR}"/*; do  
            [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
            if [ -f "$file" ];then
                chantitle=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                chanid=$(grep -m 1 "<yt:channelId>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                thisfiledata=$(sed -n '/<entry>/,$p' "$file" | grep  -e "<yt:videoId>" -e "<title>" -e "<published>" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | sed 's/|//g'| sed 'N;N;s/\n/|/g' | sed 's/&quot;/‘/g' | sed 's/&amp;/and/g' | awk -F '|' '{print $2 " | " $3 " | " $1}' | sed "s/^/\[$chantitle\] /")
                allfiledata="$allfiledata\\n$thisfiledata"
            else
                echo "Error in reading chronological list!"
            fi
        done
        if [ -f "${CACHEDIR}"/watched_files.txt ];then
            # Filter and prepend § Exit
            {
                echo "§ Exit"
                echo "-----------" >> /home/steven/tmp/output.txt
                echo "$allfiledata" >> /home/steven/tmp/output.txt
                echo "-----------" >> /home/steven/tmp/output.txt
                while IFS= read -r line; do
                    echo "** $line"  >> /home/steven/tmp/output.txt
                    id="${line##*| }"  # Extract the string after the last "| "
                    command=$(printf "%s -c -- \"%s\" \"%s\"" "${grep_bin}" "${id}" "${CACHEDIR}/watched_files.txt")
                    count=$(eval "${command}")
                    if [ "$count" == "" ];then
                        count=0
                    fi
                    if [ $count -ge 1 ]; then
                        echo "👀 $line" 
                    else
                        echo "$line" 
                    fi
                done <<< "$(echo -e "$allfiledata" | sort -r -t '|' -k 2)"
            
            }
        else
            { echo "§ Exit"; echo -e "$allfiledata" | sort -r -t '|' -k 2; }
        fi
        #echo -e "$allfiledata" | sort -r -t '|' -k 2
    fi       
}

choose_subscription () {

    allchanneldata=""
    for file in "$CACHEDIR"/*; do  
        id=$(grep -m 1 "<yt:channelId>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
        updated=$(grep -m 2 "<updated>" "$file" |tail -1 | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' )
        title=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | sed 's/|//g'| sed 'N;N;s/\n/|/g' | sed 's/&quot;/‘/g' | sed 's/&amp;/and/g' )
        if [ -n "$id" ];then
            thischanneldata=$(printf "%s \t\t\t\t|%s|%s" "$title" "$id" "$updated")
            allchanneldata=$(echo -e "$allchanneldata\\n$thischanneldata")
            thischanneldata=""
        fi
    done
    
    rezult=$(printf "1-By name A-Z\n2-By last updated\n3-By name Z-a" | rofi -i -dmenu -p "Sort how?" -theme DarkBlue)
    case $rezult in 
        1-*) allchanneldata=$(echo -e "$allchanneldata" | sort -t '|' -k 1 );;
        2-*) allchanneldata=$(echo -e "$allchanneldata" | sort -r -t '|' -k 3 );;
        3-*) allchanneldata=$(echo -e "$allchanneldata" | sort -r -t '|' -k 1 );;
    esac

    channelloop=yes
    
    while [ "$channelloop" == "yes" ];do 
        ChosenChannel=$(echo "$allchanneldata" | rofi -i -dmenu -p "Which Channel?" -theme DarkBlue | awk -F '|' '{ print $2 }')    
        if [ -f "$CACHEDIR"/"$ChosenChannel" ];then
            loop=yes
            while [ "$loop" == "yes" ];do 
                ChosenString=$(sed -n '/<entry>/,$p' "$CACHEDIR"/"$ChosenChannel" | grep -e "<yt:videoId>" -e "<title>" -e "<published>" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | sed 's/|//g'| sed 'N;N;s/\n/|/g' | sed 's/&quot;/‘/g' | sed 's/&amp;/and/g' | head -5 | awk -F '|' '{print $2 " | " $3 " |" $1}' | rofi -i -dmenu -p "Which Channel?" -theme DarkBlue)
                if [ -n "$ChosenString" ];then
                    if [[ "$ChosenString" == "#"* ]] || [[ "$ChosenString" == §* ]] || [[ "$ChosenString" == "" ]] ;then
                        #Exit condition
                        loop=""
                    else
                        VideoId=$(echo "$ChosenString" | awk -F '|' '{print $3}'| sed -e 's/^[ \t]*//')
                        play_video "$VideoId"
                    fi
                else
                    #Exit condition
                    loop=""
                fi
            done
        else
            channelloop=""
        fi
    done
    
}

choose_video () {
    loop="yes"
    while [ "$loop" == "yes" ]; do
        loud "Choose Video Loop"
        ChosenString=""
        if [ "$1" == "g" ];then 
            ChosenString=$(parse_subscriptions g 2>/dev/null | rofi -i -dmenu -p "Which video?" -theme ${ROFI_THEME})
        else
            ChosenString=$(parse_subscriptions 2>/dev/null | rofi -i -dmenu -p "Which video?" -theme ${ROFI_THEME})
        fi
        if [ "${ChosenString}" == "Error in reading subscriptions list!" ];then
            exit 98
        fi
        if [ "${ChosenString}" == "Error in reading chronological list!" ];then
            exit 97
        fi
        loud "*${ChosenString}*"  
        if [[ $ChosenString =~ ^§ ]];then
            loop="no"
            exit
        fi
        if [[ "$ChosenString" == "" ]];then
            loop="no"
            exit
        fi        
        if [ -n "$ChosenString" ];then
                VideoId=$(echo "$ChosenString" | awk -F '|' '{print $3}'| sed -e 's/^[ \t]*//')
                echo "${VideoId}"
                play_video "${VideoId}"
        else
            loop="no"
            exit
        fi
    done
}

play_video () {
    TheVideo="${1}"
    echo "youtube ${TheVideo}" >> "${CACHEDIR}"/watched_files.txt
    "${ytube_bin}" https://www.youtube.com/watch?v="${TheVideo}" -o - --ignore-errors --cookies-from-browser firefox --no-check-certificate --no-playlist --mark-watched --continue | "${mpv_bin}" - -force-seekable=yes 5
}

##############################################################################
# Main loop
##############################################################################

while [ $# -gt 0 ]; do
##############################################################################
# Get command-line parameters
##############################################################################

# You have to have the shift or else it will keep looping...
    option="$1"
    case $option in
        --loud)     export LOUD=1
                    shift
                    ;;
        --help|-h)     display_help
                    exit
                    ;;
        --import|-i)   shift
                    if [ -f "${1}" ];then 
                        InputFile="${1}"
                        import_subscriptions "$InputFile"
                    else
                        loud "Import must have a csv inputfile following."
                        exit 96
                    fi
                    shift
                    ;;
        --grouped|-g) 
            choose_video g 
            exit
            ;;
        --time|--chronological|-t|-c) 
            choose_video c 
            exit
            ;;
        --subscription|-s) 
            choose_subscription 
            exit
            ;;
        *)  display_help
            exit
            ;;
    esac
done   




