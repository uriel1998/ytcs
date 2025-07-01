# ytcs

A simple little utility to get your exported subscriptions:

Import subscriptions from CSV such as exported from YouTube or FreeTube

`./ytcs.sh --import [/path/to/csv]`

refresh those subscription RSS feeds (do this as a cronjob):

`./ytcs.sh --refresh`

present them in a rofi menu in chronological order:

`./ytcs.sh --t`

grouped by subscription (the most recent MAX_GROUPED_VIDS, default 5):

`./ytcs.sh --g`

or browse through subscriptions:

`./ytcs.sh --subscription`

Requires mpv working with yt-dlp or youtube-dl, awk, sed, grep.
 
MAX_CHANNEL_AGE - for grouped, any channel without a video newer than that will not be shown. Default 6 months.

TODO - sort grouped by channel age
TODO - get browse by subscription working
