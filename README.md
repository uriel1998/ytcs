# ytcs

`ytcs.sh` fetches YouTube channel feeds, lets you browse them with `fzf`, and plays videos with `mpv` and `yt-dlp`.

## Features

- Browse videos by channel, grouped by channel, or in reverse chronological order.
- Queue multiple videos from grouped and chronological views with `Tab`, then play them sequentially.
- Mark watched videos and show age indicators in the list.
- Preview feed descriptions and thumbnails in `fzf`.
- Import subscriptions from CSV or add one directly from a YouTube URL.
- Optionally relaunch in a dedicated kitty window.
- Optionally exclude Shorts from listing views.

## Requirements

Required for normal use:

- `mpv`
- `fzf`
- `yt-dlp` or `youtube-dl`
- `curl` or `wget` for fetching feeds

Recommended:

- `curl`

Optional:

- `xmlstarlet` for faster and more reliable XML parsing
- `timg` for thumbnail previews
- `jq` for `--addsub` when resolving YouTube handle URLs
- `kitty` and `wmctrl` for `--kitty`
- `xclip` and/or `copyq` for copying the current video URL to the clipboard

## Installation

Clone the repository and make the script executable if needed:

```bash
git clone <repo-url>
cd ytcs
chmod +x ytcs.sh
```

Copy the example environment file and edit it for your setup:

```bash
cp ytcs.env.example ytcs.env
```

If you want cache files to live inside the repository directory, create `./cache`. Otherwise `ytcs` uses `${XDG_DATA_HOME:-$HOME/.local/share}/ytcs`.

## Usage

Play a single video URL:

```bash
./ytcs.sh 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Open the interactive launcher:

```bash
./ytcs.sh
```

Refresh all cached feeds:

```bash
./ytcs.sh --refresh
```

Browse grouped by channel:

```bash
./ytcs.sh --grouped
```

Browse in chronological order:

```bash
./ytcs.sh --time
```

Browse by channel:

```bash
./ytcs.sh --subscription
```

Browse without Shorts:

```bash
./ytcs.sh --time --noshorts
```

Import subscriptions from CSV:

```bash
./ytcs.sh --import /path/to/subscriptions.csv
```

Add one subscription from a YouTube URL:

```bash
./ytcs.sh --addsub 'https://www.youtube.com/@kurzgesagt'
```

Launch in a dedicated kitty window:

```bash
./ytcs.sh --kitty --time
```

Show help:

```bash
./ytcs.sh --help
```

## Command-line options

- `--help`, `-h`: Show help text.
- `--loud`, `-l`: Print progress and diagnostic output to stderr.
- `--cli`: Enable CLI mode.
- `--kitty`: Relaunch in a dedicated kitty window using `ytcs-kitty.conf`.
- `--refresh`, `-r`: Refresh cached subscription feeds and rebuild grouped/time caches.
- `--noshorts`, `-n`: Exclude entries marked as Shorts from listing views.
- `--import`, `-i FILE`: Import subscriptions from a CSV file in channel-id export format.
- `--addsub URL`: Add one subscription from a YouTube handle URL or `/channel/` URL.
- `--subscription`, `-s`: Browse videos by channel.
- `--grouped`, `-g`: Browse videos grouped by channel.
- `--time`, `--chronological`, `-t`, `-c`: Browse videos in reverse chronological order.

If no arguments are provided, `ytcs.sh` opens an `fzf` multi-select launcher for the main actions.

## fzf behavior

- `Enter`: run the selected action or play the selected video
- `Esc`: cancel the current view
- `Tab`: queue multiple videos in grouped and chronological views
- typing filters the list

Video previews show:

- the feed entry description
- the cached thumbnail when `timg` is installed

In `--kitty` mode, the preview pane is shown below the list instead of beside it.

## Configuration

The default configuration in `ytcs.env.example` is:

```bash
export MAX_CHANNEL_AGE=182
export MAX_GROUPED_VIDS=10
#export watchtop=4
export LOUD=0
export YTDLP_COOKIES="firefox"
export MARK_AGE="TRUE"
export GEOMETRY1="1366x768+50%+50%"
export GEOMETRY2="1366x768"
export CLIMODE=0
# This is if you have a special case for the provider server being on a
# nonstandard port or machine ONLY, see https://github.com/Brainicism/bgutil-ytdlp-pot-provider?tab=readme-ov-file#usage
export YTPOT_BASEURL="youtubepot-bgutilhttp:base_url=http://127.0.0.1:8080"
export YTUBE_API_KEY=""
```

Important settings:

- `MAX_CHANNEL_AGE`: Maximum channel age in days for grouped view.
- `MAX_GROUPED_VIDS`: Maximum videos shown per channel in grouped view.
- `watchtop`: Maximum concurrent workers for feed refresh and parsing. If unset, `ytcs` uses up to the number of CPU cores.
- `YTDLP_COOKIES`: Browser profile source for `yt-dlp` cookies.
- `MARK_AGE`: Enable or disable age markers in lists.
- `GEOMETRY1`, `GEOMETRY2`: `mpv` window geometry options.
- `YTPOT_BASEURL`: Optional extractor args for the BGUtil POTS provider.
- `YTUBE_API_KEY`: Required for resolving handle URLs in `--addsub` when using `@handle` inputs.

## Notes

- Feed data is cached in `./cache` when that directory exists beside the script. Otherwise it is cached under `${XDG_DATA_HOME:-$HOME/.local/share}/ytcs`.
- `grouped_data.txt`, `time_data.txt`, and `parsed_time/` are derived caches.
- `--refresh` refreshes channel XML feeds and rebuilds grouped and chronological caches.
- `--time` reuses an existing valid time cache and only rebuilds it when the cache is missing or invalid.
- Feed refresh now preserves the old cached XML if the fetched response is invalid or looks like an error page.
- `--addsub` clears grouped/time caches so they rebuild on next use.
- Playback still passes `--mark-watched` to `yt-dlp`, and `ytcs` also records local watched state in `watched_files.txt` after the playback pipeline exits.
- During playback, the script updates local watched markers inline in `grouped_data.txt` and `time_data.txt` when those cache files exist.
- The script copies the current video URL to `xclip` and/or `copyq` when available.
- `--addsub` supports direct `/channel/...` URLs and handle URLs such as `https://www.youtube.com/@kurzgesagt`.
- If `YTUBE_API_KEY` is not set for handle resolution, the script points to TunePocket's channel ID finder:
  `https://www.tunepocket.com/youtube-channel-id-finder/#channle-id-finder-form`
- Some YouTube channels may not currently expose a working RSS feed even when the channel page itself exists.

## License

MIT
