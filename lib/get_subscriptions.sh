#!/bin/bash

if [ -z "$SCRIPTDIR" ];then 
    # Not sourced by my code
    export SCRIPTDIR="$( cd "$(dirname "$0")" ; pwd -P )"
fi

if [ -z "$CACHEDIR" ];then 
    # Not sourced by my code
    export CACHEDIR=$(echo "$SCRIPTDIR" | awk -F '/' '{sub(FS $NF,x); print $0"/cache"}')
fi

get_subscriptions() 
{
    
    if [ -z "$SUBSCRIPTIONFILE" ];then
        SUBSCRIPTIONFILE="$1"
    fi
 
    
    while read line; do
        id=$(echo "$line"|awk -F ',' '{print $1}')
        url=$(echo "$line"|awk -F ',' '{print $2}')
        name=$(echo "$line"|awk -F ',' '{print $3}')
        if [[ "$id" != "Channel Id" ]];then
            wget_string=$(printf "wget \"%s%s\" -O %s/%s"  "https://www.youtube.com/feeds/videos.xml?channel_id=" "$id" "$CACHEDIR" "$id") 
            echo "${wget_string}"
            sleep 5
            eval "${wget_string}"
        fi
    done < "$SUBSCRIPTIONFILE"
}


parse_subscriptions(){
    
    if [ "$1" = "g" ];then
        # this is per subscription, latest 5 
        for file in "$CACHEDIR"/*; do  
            ChanSubFile=""
            if [ -f "$file" ];then
                chantitle=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                chanid=$(grep -m 1 "<yt:channelId>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                echo "-------------------------------------------------"
                printf "%s\n" "$chantitle"
                echo "-------------------------------------------------"
                sed -n '/<entry>/,$p' "$file" | grep -e "<yt:videoId>" -e "<title>" -e "<published>" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | sed 's/|//g'| sed 'N;N;s/\n/|/g' | sed 's/&quot;/‘/g' | head -5 | awk -F '|' '{print $2 " | " $3 " | " $1}'
            else
                echo "ERRROROR  ERRORORR DOES NOT COMPUTE"
            fi
        done
    else
        # This is chronological, all subscriptions
        for file in "$CACHEDIR"/*; do  
            ChanSubFile=""
            if [ -f "$file" ];then
                chantitle=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                chanid=$(grep -m 1 "<yt:channelId>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                
                thisfiledata=$(sed -n '/<entry>/,$p' "$file" | grep  -e "<yt:videoId>" -e "<title>" -e "<published>" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | sed 's/|//g'| sed 'N;N;s/\n/|/g' | sed 's/&quot;/‘/g' | awk -F '|' '{print $2 " | " $3 " | " $1}')
                allfiledata="$allfiledata\\n$thisfiledata"
                
            else
                echo "ERRROROR  ERRORORR DOES NOT COMPUTE"
            fi
        done
        echo -e "$allfiledata" | sort -t '|' -k 2
    fi       
}

##############################################################################
# Are we sourced?
# From http://stackoverflow.com/questions/2683279/ddg#34642589
##############################################################################

# Try to execute a `return` statement,
# but do it in a sub-shell and catch the results.
# If this script isn't sourced, that will raise an error.
$(return >/dev/null 2>&1)

# What exit code did that give?
if [ "$?" -eq "0" ];then
    echo "[info] Function ready to go."
    OUTPUT=0
else
    OUTPUT=1
    if [ "$#" = 0 ];then
        parse_subscriptions
    else
        if [ -f "${1}" ];then 
            InputFile="${1}"
            get_subscriptions "$InputFile"
        else
            parse_subscriptions "$1"
        fi
    fi
fi
