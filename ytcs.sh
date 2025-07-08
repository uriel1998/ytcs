#!/bin/bash


##############################################################################
#
#  ytcs -- to scroll through and view youtube videos 
#  through RSS feeds and yt-dlp and mpv
#  
#  (c) Steven Saus 2025
#  Licensed under the MIT license
#
##############################################################################

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
watchtop=""
if [ -f "${SCRIPT_DIR}/ytcs.env" ];then
    source "${SCRIPT_DIR}/ytcs.env"
else
    export ROFI_THEME="arthur"
    export MAX_CHANNEL_AGE=182
    export MAX_GROUPED_VIDS=10
    export YTDLP_COOKIES="firefox"
    export MARK_AGE="TRUE"
    export GEOMETRY1="1366x768+50%+50%"
    export GEOMETRY2="1366x768"
fi

if [ -z "${XDG_DATA_HOME}" ];then
    export XDG_DATA_HOME="${HOME}/.local/share"
    export XDG_CONFIG_HOME="${HOME}/.config"
fi

CACHEDIR="${XDG_DATA_HOME}/ytcs"
if [ ! -d "${CACHEDIR}" ];then
    mkdir -p "${CACHEDIR}"
fi
wget_bin=$(which wget)
mpv_bin=$(which mpv)
grep_bin=$(which grep)
ytube_bin=$(which youtube-dl)
dlp=$(which yt-dlp)
if [ "$dlp" != "" ];then
    ytube_bin="${dlp}"
fi

# Some error checking so you don't make more spawns than cores
if [ "$watchtop" == "" ];then
    if [ -f $(which nproc) ];then
        watchtop=$(nproc)
    else
        watchtop=1
    fi
else
    if [ -f $(which nproc) ];then
        if [ $watchtop -gt $(nproc) ];then
            watchtop=$(nproc)
        fi
    else
        watchtop=1
    fi
fi

function loud() {
##############################################################################
# loud outputs on stderr 
##############################################################################    
    if [ $LOUD -eq 1 ];then
        echo "$@" 1>&2
        # Strip ANSI escape codes and replace invalid UTF-8 with ?
        local message
        message=$(echo "${@}" | LC_ALL=C sed 's/\x1B\[[0-9;]*[a-zA-Z]//g' | iconv -f utf-8 -t utf-8//IGNORE)
        notify-send "${message}" --icon youtube --urgency=low
    fi
}
 
display_help(){
##############################################################################
# Show the Help
##############################################################################    
    echo "###################################################################"
    echo "# ytcs.sh [--loud] [--help] [--import] [--refresh] [--subscription|--grouped|--time]"
    echo "# --loud: Extra feedback, including notify-send (should be FIRST)"
    echo "# --help - shows this"
    echo "# --import /path/to/csv: Import CSV of subscriptions"
    echo "# --refresh: refresh subscriptions"
    echo "# Choose only ONE of these three as the LAST switch"
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
    watchcount=0
    while read line; do
        if [ $watchcount -gt $watchtop ];then
            wait
            watchcount=0
        fi
        watchcount=$(( watchcount + 1 ))  
        (
        id=$(echo "$line"|awk -F ',' '{print $1}')
        #url=$(echo "$line"|awk -F ',' '{print $2}')
        #name=$(echo "$line"|awk -F ',' '{print $3}')
        if [[ "$id" != "Channel Id" ]];then
            wget_string=$(printf "%s -q \"%s%s\" -O %s/%s" "${wget_bin}" "https://www.youtube.com/feeds/videos.xml?channel_id=" "${id}" "${CACHEDIR}" "${id}") 
            eval "${wget_string}"
        fi
        ) &
    done < "$SUBSCRIPTIONFILE"
    exit
}

refresh_subscriptions() {
    loud "[info] Refreshing subscriptions"
    watchcount=0
    for file in "$CACHEDIR"/*; do  
        [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
        [[ "$(basename "$file")" == "grouped_data.txt" ]] && continue
        [[ "$(basename "$file")" == "time_data.txt" ]] && continue    
        if [ $watchcount -gt $watchtop ];then
            wait
            watchcount=0
        fi
        watchcount=$(( watchcount + 1 ))  
        (
        id=$(basename ${file})
        if [ -f "$file" ];then
            wget_string=$(printf "%s -q \"%s%s\" -O %s/%s" "${wget_bin}" "https://www.youtube.com/feeds/videos.xml?channel_id=" "$id" "$CACHEDIR" "$id") 
            #echo "${wget_string}"
            eval "${wget_string}"
        fi
        id="" ) &
    done
    loud "[info] Refreshing grouped data"
    parse_subscriptions g 2>/dev/null > "${CACHEDIR}/grouped_data.txt"        
    loud "[info] Refreshing chronological data"
    parse_subscriptions 2>/dev/null > "${CACHEDIR}/time_data.txt"
    loud "[info] Refresh complete"
}

is_file_newer_than_any_xml() {
    local dir="$1"
    local file="$2"

    # Make sure both directory and file exist
    [[ ! -d "$dir" || ! -f "$file" ]] && return 1

    local file_ts
    file_ts=$(stat -c %Y "$file")
    # Loop through files in the directory

    for file in "${dir}"/*; do  
        [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
        [[ "$(basename "$file")" == "grouped_data.txt" ]] && continue
        [[ "$(basename "$file")" == "time_data.txt" ]] && continue
        [[ ! -e "$file" ]] && continue  # in case no matches
        xml_ts=$(stat -c %Y "$file")
        if (( file_ts > xml_ts )); then
            return 0  # the file is newer than at least one .xml
        fi
    done

    return 1  # file is not newer than any .xml
}

is_file_newer() {
    local file1="$1"
    local file2="$2"

    # Make sure both directory and file exist
    [[ ! -f "$file1" || ! -f "$file2" ]] && return 1

    local file_ts
    local file2_ts
    file1_ts=$(stat -c %Y "$file1")
    file2_ts=$(stat -c %Y "$file2")
    if (( file1_ts > file2_ts )); then
        return 0  # the file is newer than at least one .xml
    else
        return 1  # file is not newer than any .xml
    fi
}

most_recent_age() {
    local data="$1"
    local latest_ts=0

    # Loop over each line
    while IFS= read -r line; do
        # Extract ISO date from second field
        date_string=$(echo "$line" | awk -F '|' '{print $2}' | xargs)
        [[ -z "$date_string" ]] && continue

        # Convert to epoch
        ts=$(date -d "$date_string" +%s 2>/dev/null)
        [[ -z "$ts" ]] && continue

        # Keep the latest (most recent) timestamp
        if (( ts > latest_ts )); then
            latest_ts=$ts
        fi
    done <<< "$data"

    # If no valid timestamp found
    if (( latest_ts == 0 )); then
        echo "N/A,N/A"
        return 1
    fi

    # Calculate age in days and weeks
    now_ts=$(date +%s)
    seconds_old=$(( now_ts - latest_ts ))
    days_old=$(( seconds_old / 86400 ))
    echo "${days_old}"
}

days_to_iso8601() {
    local days_ago="$1"
    date -u -d "$days_ago days ago" +"%Y-%m-%dT%H:%M:%S+00:00"
}

add_human_date() {
    while IFS= read -r line; do
        # Use Bash pattern matching to extract the ISO date
        if [[ "$line" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\+00:00) ]]; then
            iso="${BASH_REMATCH[1]}"
            human=$(date -d "$iso" "+%-d %B %Y")
            # Replace the ISO date with human | ISO
            echo "${line//$iso/$human | $iso}"
        else
            echo "$line"
        fi
    done
}

mark_if_watched() {
    local data="$@"
    if [ -f "${CACHEDIR}"/watched_files.txt ];then
        # Filter and prepend § Exit
        {
            echo "§ Exit"
            while IFS= read -r line; do
                [[ "${line}" == "" ]] && continue
                if [[ $line == *"📺"* ]];then
                    printf "\n%s\n" "${line}"
                else
                    id=$(echo "${line}" | awk -F'|' '{print $NF}' )  # Extract the string after the last "| "
                    command=$(printf "%s -c -- \"%s\" \"%s\"" "${grep_bin}" "${id}" "${CACHEDIR}/watched_files.txt")
                    count=$(eval "${command}")
                    if [ "$count" == "" ];then
                        count=0
                    fi
                    if [ $count -ge 1 ]; then
                        printf "👀 %s\n" "${line}" | mark_age | add_human_date
                    else
                        printf "%s\n" "${line}" | mark_age | add_human_date
                    fi
                fi
            done <<< "$(echo "${data}")"
        }
    else
        { echo "§ Exit"; echo -e "$data"; }
    fi                 

}

mark_age() {
    local one_week_ago two_weeks_ago three_weeks_ago four_weeks_ago five_weeks_ago \
      six_weeks_ago seven_weeks_ago eight_weeks_ago nine_weeks_ago ten_weeks_ago \
      line date_string line_ts

    one_week_ago=$(date -d '7 days ago' +%s)
    two_weeks_ago=$(date -d '14 days ago' +%s)
    three_weeks_ago=$(date -d '21 days ago' +%s)
    four_weeks_ago=$(date -d '28 days ago' +%s)
    five_weeks_ago=$(date -d '35 days ago' +%s)
    six_weeks_ago=$(date -d '42 days ago' +%s)
    seven_weeks_ago=$(date -d '49 days ago' +%s)
    #eight_weeks_ago=$(date -d '56 days ago' +%s)
    #nine_weeks_ago=$(date -d '63 days ago' +%s)
    #ten_weeks_ago=$(date -d '70 days ago' +%s)

    while IFS= read -r line; do
        if [ "${MARK_AGE}" == "TRUE" ];then
            # Extract the ISO date from field 2 (trimmed)
            if [[ $line == *📺* ]];then
                days_ago=$(echo "$line" | awk -F '-' '{print $2}' | xargs)
                date_string=$(days_to_iso8601 $days_ago)
                line_ts=$(date -d "$date_string" +%s 2>/dev/null)
            else
                date_string=$(echo "$line" | awk -F '|' '{print $2}' | xargs)
                line_ts=$(date -d "$date_string" +%s 2>/dev/null)
            fi
            if [[ -z "$line_ts" ]]; then
                echo "$line"
                continue
            fi

            if (( line_ts < seven_weeks_ago )); then
                echo "▁ $line"
            elif (( line_ts < six_weeks_ago )); then
                echo "▂ $line"
            elif (( line_ts < five_weeks_ago )); then
                echo "▃ $line"
            elif (( line_ts < four_weeks_ago )); then
                echo "▄ $line"
            elif (( line_ts < three_weeks_ago )); then
                echo "▅ $line"
            elif (( line_ts < two_weeks_ago )); then
                echo "▆ $line"
            elif (( line_ts < one_week_ago )); then
                echo "▇ $line"
            else
                echo "█ $line"
            fi
        else
            echo " $line"
        fi
    done  
}

parse_subscriptions(){
    trap '' PIPE
    allfiledata=""
    if [ "$1" = "g" ];then
        # this is per subscription, latest MAX_GROUPED_VIDS 
        TEMPFILE=$(mktemp)
        shopt -s nullglob  # avoids looping if no match
        watchcount=0
        for file in "${CACHEDIR}"/*; do  
            [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
            [[ "$(basename "$file")" == "grouped_data.txt" ]] && continue
            [[ "$(basename "$file")" == "time_data.txt" ]] && continue
            if [ $watchcount -gt $watchtop ];then
                wait
                watchcount=0
            fi
            watchcount=$(( watchcount + 1 ))  
            (
            if [ -f "$file" ];then
                chantitle=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                chanid=$(grep -m 1 "<yt:channelId>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                thischanneldata=$(sed -n '/<entry>/,$p' "$file" | grep -e "<yt:videoId>" -e "<title>" -e "<published>" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | sed 's/|//g'| sed 'N;N;s/\n/|/g' | sed 's/&quot;/‘/g' | sed 's/&amp;/and/g' | head -${MAX_GROUPED_VIDS} | awk -F '|' '{print $2 " | " $3 " |" $1}')
                thischannelage=$(most_recent_age "$thischanneldata")
                thischanneltitle=$(printf "§ 📺 %s - %s" "$chantitle" "$thischannelage")
                if [ $thischannelage -le $MAX_CHANNEL_AGE ];then
                    printf "\n%s\n%s\n" "$thischanneltitle" "$thischanneldata" >> "${TEMPFILE}"
                fi
            else
                echo "Error in reading subscriptions list!"
            fi ) &
        done
        wait
        allfiledata=$(cat ${TEMPFILE})
        mark_if_watched "${allfiledata}"
        rm "${TEMPFILE}"   
    else
        # This is chronological, all subscriptions
        shopt -s nullglob  # avoids looping if no match
        for file in "${CACHEDIR}"/*; do  
            [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
            [[ "$(basename "$file")" == "grouped_data.txt" ]] && continue
            [[ "$(basename "$file")" == "time_data.txt" ]] && continue
            if [ -f "$file" ];then
                chantitle=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                #chanid=$(grep -m 1 "<yt:channelId>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                thisfiledata=$(sed -n '/<entry>/,$p' "$file" | grep  -e "<yt:videoId>" -e "<title>" -e "<published>" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | sed 's/|//g'| sed 'N;N;s/\n/|/g' | sed 's/&quot;/‘/g' | sed 's/&amp;/and/g' | awk -F '|' '{print $2 " | " $3 " | " $1}' | sed "s/^/\[$chantitle\] /")
                allfiledata="$allfiledata\\n$thisfiledata"
            else
                echo "Error in reading chronological list!"
            fi
        done
        
        mark_if_watched "$(echo -e "$allfiledata" | sort -r -t '|' -k 2)"
    fi       
}
 

choose_subscription () {
    TEMPFILE=$(mktemp)
    allchanneldata=""
    watchcount=0
    for file in "$CACHEDIR"/*; do 
        [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
        [[ "$(basename "$file")" == "grouped_data.txt" ]] && continue
        [[ "$(basename "$file")" == "time_data.txt" ]] && continue
        if [ $watchcount -gt $watchtop ];then
            wait
            watchcount=0
        fi
        watchcount=$(( watchcount + 1 ))  
        (
        id=$(basename ${file}) 
        updated=$(grep -m 2 "<updated>" "$file" | tail -1 | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' )
        human_date=$(date -d "$updated" +"%d %B")
        title=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | sed 's/|//g'| sed 'N;N;s/\n/|/g' | sed 's/&quot;/‘/g' | sed 's/&amp;/and/g' )
        if [ -n "$id" ];then
            printf "%s (%s)\t\t\t\t|%s|%s\n" "$title" "$human_date" "$id" "$updated" >> "${TEMPFILE}"
        fi
        ) &
    done
    # the awk omits those who don't have an updated date (and are therefore ill-formed)
    rezult=$(printf "1-By last updated\n2-By name A-Z\n3-By name Z-a\n" | rofi -i -dmenu -p "Sort how?" -theme "${ROFI_THEME}")
    case $rezult in 
        1-*) allchanneldata=$({ echo "§ Exit"; cat "${TEMPFILE}" | awk -F'|' 'NF && $3 != ""' | sort -r -t '|' -k 3; });;
        2-*) allchanneldata=$({ echo "§ Exit"; cat "${TEMPFILE}" | awk -F'|' 'NF && $3 != ""' | sort -t '|' -k 1; });;
        3-*) allchanneldata=$({ echo "§ Exit"; cat "${TEMPFILE}" | awk -F'|' 'NF && $3 != ""' | sort -r -t '|' -k 1; });;
    esac
    rm "${TEMPFILE}"
    channelloop=yes
    
    while [ "$channelloop" == "yes" ];do 
        ChosenChannel=$(echo "$allchanneldata" | rofi -i -dmenu -p "Which Channel?" -theme "${ROFI_THEME}" | awk -F '|' '{ print $2 }')    
        if [ -f "$CACHEDIR"/"$ChosenChannel" ];then
            loop=yes
            while [ "$loop" == "yes" ];do 
                # ADD IN WATCHED CHECK HERE
                ChosenString=$(mark_if_watched "$(sed -n '/<entry>/,$p' "$CACHEDIR"/"$ChosenChannel" \
                    | grep -e "<yt:videoId>" -e "<title>" -e "<published>" \
                    | awk -F '>' '{print $2}' \
                    | awk -F '<' '{print $1}' \
                    | sed 's/|//g' \
                    | sed 'N;N;s/\n/|/g' \
                    | sed 's/&quot;/‘/g' \
                    | sed 's/&amp;/and/g' \
                    | head -25 \
                    | awk -F '|' '{printf "%s | %s | %s\n", $2, $3, $1}'
                )" | rofi -i -dmenu -p "Which VIDEO?" -theme "${ROFI_THEME}")
                if [ -n "$ChosenString" ];then
                    if [[ "$ChosenString" == "#"* ]] || [[ "$ChosenString" == §* ]] || [[ "$ChosenString" == "" ]] ;then
                        #Exit condition
                        loop=""
                    else
                        VideoId=$(echo "$ChosenString" | awk -F '|' '{print $4}'| sed -e 's/^[ \t]*//')
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
        ChosenString=""
        if [ "$1" == "g" ];then 
            if is_file_newer_than_any_xml "${CACHEDIR}" "${CACHEDIR}/grouped_data.txt"; then
                loud "[info] Loading time data file, one moment..."
            else
                loud "[info] Rebuilding grouped data file, one moment..."
                parse_subscriptions g 2>/dev/null > "${CACHEDIR}/grouped_data.txt"
            fi
            feeddata=$(<"${CACHEDIR}/grouped_data.txt")
        else
            if is_file_newer_than_any_xml "${CACHEDIR}" "${CACHEDIR}/time_data.txt"; then
                loud "[info] Loading time data file, one moment..."
                
            else
                loud "[info] Rebuilding time data file, one moment..."
                parse_subscriptions 2>/dev/null > "${CACHEDIR}/time_data.txt"
            fi
            feeddata=$(<"${CACHEDIR}/time_data.txt")
        fi
        # I guess it could just read from a file here, but... ah well.
        ChosenString=$(echo "$feeddata" | fzf)
        ChosenString=$(echo "$feeddata" | rofi -i -dmenu -p "Which video?" -theme ${ROFI_THEME})
        exit
        if [ "${ChosenString}" == "Error in reading subscriptions list!" ];then
            exit 98
        fi
        if [ "${ChosenString}" == "Error in reading chronological list!" ];then
            exit 97
        fi
        if [[ $ChosenString =~ ^§ ]] || [[ "$ChosenString" == "" ]];then
            loop="no"
        else 
            if [ -n "$ChosenString" ];then
                VideoId=$(echo "$ChosenString" | awk -F '|' '{print $4}'| sed -e 's/^[ \t]*//')
                VideoTitle=$(echo "$ChosenString" | awk -F '|' '{print $1}')
                echo "${VideoId}"
                play_video "${VideoId}" "${VideoTitle}"
            else
                loop="no"
            fi
        fi
        if [ "$loop" != "yes" ];then
            break
        fi
    done
}

to_clipboards (){
    input="${1}"
    if [ -f $(which xclip) ];then
        echo "${input}" | xclip -i -selection primary -r 
        echo "${input}" | xclip -i -selection secondary -r 
        echo "${input}" | xclip -i -selection clipboard -r 
    fi
    if [ -f $(which copyq) ];then
        echo "${input}" | tr -d '/n' | /usr/bin/copyq write 0  - 
        /usr/bin/copyq select 0
    fi
}

play_video () {
    TheVideo="${1}"
    TheTitle=$(echo "${2}" | cut -c 2- | sed 's/👀//g' )
    if [ -f $(which notify-send) ];then
        loud "Loading video ${TheTitle}..."
    fi
    
    # copy url to clipboards
    to_clipboards "https://www.youtube.com/watch?v=${TheVideo}"
 
    video_url="https://www.youtube.com/watch?v=${TheVideo}"
    # Run yt-dlp and mpv in a monitored pipeline
    { "${ytube_bin}" "$video_url" \
        -o - \
        --ignore-errors \
        --cookies-from-browser "${YTDLP_COOKIES}" \
        --no-check-certificate \
        --no-playlist \
        --mark-watched \
        --continue \
        | "${mpv_bin}" --geometry=${GEOMETRY1} --autofit=${GEOMETRY2} - --force-seekable=yes; 
    } || {
        echo "Pipeline exited or mpv was terminated"
        pkill -P $$ "${ytube_bin##*/}" 2>/dev/null
    }
    
    command=$(printf "%s -c -- \"%s\" \"%s\"" "${grep_bin}" "${TheVideo}" "${CACHEDIR}/watched_files.txt")
    count=$(eval "${command}")
    if [ "$count" == "0" ];then
        loud "[info] Marking watched"
        echo "youtube ${TheVideo}" >> "${CACHEDIR}"/watched_files.txt
    else
        loud "[info] Already watched"
    fi    
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
        --loud|-l)     export LOUD=1
                    shift
                    ;;
        --refresh|-r)  refresh_subscriptions
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
            if is_file_newer "${CACHEDIR}/watched_files.txt" "${CACHEDIR}/grouped_data.txt"; then
                loud "[info] Refreshing grouped data on exit"
                parse_subscriptions g 2>/dev/null > "${CACHEDIR}/grouped_data.txt"
                loud "[info] Finished refreshing grouped data on exit"
            fi
            exit
            ;;
        --time|--chronological|-t|-c) 
            choose_video c
            if is_file_newer "${CACHEDIR}/watched_files.txt" "${CACHEDIR}/time_data.txt"; then
                loud "[info] Refreshing chronological data on exit"
                parse_subscriptions 2>/dev/null > "${CACHEDIR}/time_data.txt"
                loud "[info] Finished refreshing chronological data on exit"
            fi
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



    

