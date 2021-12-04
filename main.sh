#!/bin/bash

SCRIPTDIR="$( cd "$(dirname "$0")" ; pwd -P )"

CACHEDIR - either ~/.cache/ytclis  or $SCRIPTDIR/cache
# init variables
# get INI
# parse args


do while
    get_subscriptions
        choose_subscription
    merge cache
    choose_video
    play_video
done
