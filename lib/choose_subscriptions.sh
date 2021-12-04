#!/bin/bash


PSEUDOCODE

    - sorting - by subscription or date?
    - get list of cache files
    - parse cached rss into simple data format 
    - feed that to rofi 
                        # Maybe don't need to do this until runtime?
            #cat "$CACHEDIR"/"$id" | grep -e "<id>" -e "<yt:videoId>" -e "<title>" -e "<published>" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' > "$CACHEDIR"/"$id".txt
    
    
    
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
        link="${1}"
        if [ ! -z "$2" ];then
            title="$2"
        fi
        DO THE FUNCTION 
    fi
fi

