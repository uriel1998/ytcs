 Youtube-CLI-Subscriptions README 
 
 This script is a simple tool to fetch YouTube subscriptions via RSS feed and watch them using mpv and youtube-dl . 
 
 It was authored by Steven Saus and is licensed under the MIT license. 
 
 The script presents the subscriptions in a rofi dropdown menu, making it easy to navigate and select the videos you want to watch.
 
 ## Prerequisites
 
 The script requires the following programs to be installed: 
 
 • youtube-dl or yt-dlp 
 • mpv 
 • rofi 
 • wget 
 
 ## Installation 
 
 This tool can be installed by cloning the repository to your local machine and then running the script. 
 
 Use the following command to clone the repository: 
 
git clone https://github.com/your-github-username/your-repo-name.git 
 
 ## Usage
 
 There are several commands available with this script: 
 
 • --loud : This command provides more verbose output for debugging.
 • --refresh : Refreshen your subscriptions.
 • --help or -h : Display help context. 
 • --import or -i : Import subscriptions from a csv file. 
 • --grouped or -g : Display the videos grouped by subscriptions. 
 • --time --chronological -t or -c : Arrange and display the videos in chronological order. 
 • --subscription or -s : Select and view videos per subscription basis.
 
 For example, you can refresh your subscriptions using the --refresh command like this:
 
./youtube-cli-subscriptions.sh --refresh 
 
 You can use the --import command to import your subscriptions from a csv file like this: 
 
./youtube-cli-subscriptions.sh --import /path/to/csv 
 
 You can also browse your videos by group, by time or by subscription using the --grouped , --time , and --subscription commands respectively. 
 
./youtube-cli-subscriptions.sh --grouped 
 
./youtube-cli-subscriptions.sh --time 
 
./youtube-cli-subscriptions.sh --subscription 
 
 ### Note
 
 Ensure that the CSV file used during the import operation is formatted properly, each line consisting of channel id, url, channel name and without a comma at 
 the end.
 
 This script is intended for personal use and not to be utilized for streaming without permission from the respective YouTube creators. Ensure you comply with 
 the terms and conditions from YouTube.
 
MAX_CHANNEL_AGE - for grouped, any channel without a video newer than that will not be shown. Default 6 months.
MAX_GROUPED_VIDS - for grouped, max per channel, default 10.

TODO - sort grouped by channel age
TODO - get browse by subscription working (it doesn't work at all right now)
