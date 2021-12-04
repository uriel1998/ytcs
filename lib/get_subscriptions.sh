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
        echo -e "Please call this as a function or with \nthe url as the first argument and optional \ndescription as the second."
    else

        InputFile="${1}"

        get_subscriptions "$InputFile"
    fi
fi

