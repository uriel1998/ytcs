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
 
 * --loud : This command provides more verbose output for debugging.
 * --refresh : Refresh your subscriptions.
 * --help or -h : Display help context (this, basically). 
 * --import or -i : Import subscriptions from a csv file. 
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
 
 Keep in mind that since it's powered by `rofi`, you can search among the titles in any of these views.
 
 
 ```
./ytcs.sh --grouped 
 
./ytcs.sh --time 
 
./ytcs.sh --subscription 
```
 
 ### Notes
 
 * Ensure that the CSV file used during the import operation is formatted properly, each line consisting of channel id, url, channel name and without a comma at 
 the end. A sample is enclosed. This is the same export format that FreeTube, for example, uses for CSV export. You can also manually find channelID using a 
 tool like the one at  [https://www.streamweasels.com/%20tools/youtube-channel-id-and-%20user-id-convertor/](https://www.streamweasels.com/%20tools/youtube-channel-id-and-%20user-id-convertor/)
 
 * The following variables are set at the top of the script
    - MAX_CHANNEL_AGE - for grouped, any channel without a video newer than that will not be shown. Default 6 months.
    - MAX_GROUPED_VIDS - for grouped, max per channel, default 10.
    - ROFI_THEME - the theme you want to use. The modified version of "arthur" I use is enclosed.
 
 *  This script is intended for personal use and not to be utilized for streaming without permission from the respective YouTube creators. Ensure you comply with 
 the terms and conditions from YouTube.
 
### TODO

TODO - I mean, it's spaghetti code. It works, it is nowhere near optimized, and is probably got issues in some way
TODO - sort grouped by channel age
TODO - set up variables in .env or something
TODO - varying video sizes defined
TODO - set up better cookie import versions.
TODO - mark watched from subscription browsing
TODO - notifications for updating, etc, for when not run from a terminal
