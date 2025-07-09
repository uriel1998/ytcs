# ytcs.sh

This script is a simple tool to fetch YouTube subscriptions via RSS feed and 
watch them using mpv and youtube-dl, thus enabling using your login cookies from
Firefox, and allowing the viewing of videos.

The script presents the subscriptions in a rofi dropdown menu, making it easy to navigate and select the videos you want to watch. 

## Prerequisites

The script requires the following programs to be installed: 

* youtube-dl or yt-dlp 
* mpv 
* rofi 
* wget 

## Installation 

This tool can be installed by cloning the repository to your local machine and then running the script. 


## Usage

There are several commands available with this script: 

ytcs.sh [--loud] [--help] [--import FILENAME] [--refresh] [--subscription|--grouped|--time]"

You may use any combination of these:

* --loud : This command provides more verbose output for debugging and notify-send. Should be FIRST.
* --refresh : Refresh your subscriptions.
* --help or -h : Display help context (this, basically). 
* --import or -i : Import subscriptions from a csv file. 

Choose ONE of the three of these:  

* --grouped or -g : Display the videos grouped by subscriptions. 
* --time --chronological -t or -c : Arrange and display the videos in chronological order. 
* --subscription or -s : Select and view videos by browsing subscriptions.

For example, you can refresh your subscriptions using the --refresh command like this:

`./ytcs.sh --refresh`

Ideally, you'd do that with a cron job; it does take a moment, and caches the 
results for quick user input.

You can use the --import command to import your subscriptions from a csv file like this: 

`./ytcs.sh --import /path/to/csv`

See the notes below.

You can also browse your videos by group, by time or by subscription using the 
--grouped , --time , and --subscription commands respectively. In grouped and 
time based view, it will compare to a watched file, and update it if you've watched
and videos.  

Keep in mind that since it's powered by `rofi` or `fzf`, you can search among the titles in any of these views.


```
./ytcs.sh --grouped 

./ytcs.sh --time 

./ytcs.sh --subscription 
```

### Configuration

Rename the file `ytcs.env.example` to `ytcs.env` and edit it. The example file has the defaults:

```
export ROFI_THEME="arthur"
export MAX_CHANNEL_AGE=182
export MAX_GROUPED_VIDS=10
#export watchtop=4
export LOUD=0
export YTDLP_COOKIES="firefox"
export MARK_AGE="TRUE"
export GEOMETRY1="1366x768+50%+50%"
export GEOMETRY2="1366x768"
```

The value `watchtop` is used for process control; while parsing data, `ytcs` will attempt to use
a number of subshells equal to your processor cores *unless* watchtop is set to a positive value to limit 
the number of cores.  

I personally use the "arthur_modified" rofi theme included here which has some small tweaks.

`YTDLP_COOKIES` is used to control which browser `yt-dlp` [gets cookies from](https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp).

`MARK_AGE` determines whether the visual marking of video age is displayed, change to anything but "TRUE" to turn off.

`GEOMETRY1` and `GEOMETRY2` are for `mpv`; they correspond to `--geometry=${GEOMETRY1} --autofit=${GEOMETRY2}`.

### Notes

* Nearly all channel data and views are cached to optimize speed when you're actually watching videos. So you will not see "watched" changes until it rebuilds that cached view after you quit the program.  Likewise, when you change a variable such as `MARK_AGE`, you *must* either use the refresh command, or delete `time_data.txt` and `grouped_data.txt` in the cache directory in order to see the change.  

* When the tool plays a video, it attempts to automatically use xclip and/or copyq to put the video URL in the clipboard, should you want to share it, etc.

* Ensure that the CSV file used during the import operation is formatted properly, each line consisting of channel id, url, channel name and without a comma at 
the end. A sample is enclosed. This is the same export format that FreeTube, for example, uses for CSV export. You can also manually find channelID using a 
tool like the one at  [https://www.streamweasels.com/%20tools/youtube-channel-id-and-%20user-id-convertor/](https://www.streamweasels.com/%20tools/youtube-channel-id-and-%20user-id-convertor/)

*  This script is intended for personal use and not to be utilized for streaming without permission from the respective YouTube creators. Ensure you comply with 
the terms and conditions from YouTube.


### TODO

TODO - Demo
TODO - I mean, it's spaghetti code. It works, it is nowhere near optimized, and is probably got issues in some way  
TODO - sort grouped by channel age (this is REALLY kicking my ass.) 
TODO - filter *EXCLUDE* terms (new feature)
TODO - locks on data files 
TODO - a way to update in the background and then swap the cache out once it's rebuilt in the background (that'd be FAB)
TODO - mark as watched needs to be done as a db rebuild simply because that *IS* how long it takes.
TODO - Or just alter the cache file ITSELF.
