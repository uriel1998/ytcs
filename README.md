# ytcs

A simple little utility to get your exported subscriptions:

Import subscriptions from CSV such as exported from YouTube or FreeTube

`./ytcs.sh --import [/path/to/csv]`

refresh those subscription RSS feeds (do this as a cronjob):

`./ytcs.sh --refresh`

present them in a rofi menu in chronological order:

`./ytcs.sh --t`

grouped by subscription:

`./ytcs.sh --g`

or browse through subscriptions:

`./ytcs.sh --subscription`

Requires mpv working with yt-dlp or youtube-dl, awk, sed, grep.
 
 
 todo -- track watched, perhaps by using yt-dlp's bank? probably best there
