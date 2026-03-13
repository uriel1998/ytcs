# ytcs

`ytcs.sh` fetches YouTube channel feeds, lets you browse them with `fzf`, and plays videos with `mpv` and `yt-dlp`.

## Features

- Browse videos by channel, grouped by channel, or in reverse chronological order.
- Mark watched videos and show age indicators in the list.
- Preview video descriptions and thumbnails in `fzf`.
- Add subscriptions from CSV or directly from a YouTube URL.
- Optionally launch in a dedicated kitty window.

## Requirements

Required:

- `mpv`
- `yt-dlp` or `youtube-dl`
- `fzf`
- `curl`
- `jq`
- `timg`

Optional:

- `xmlstarlet`
- `kitty`
- `wmctrl`
- `xclip`
- `copyq`

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

Import subscriptions from CSV:

```bash
./ytcs.sh --import /path/to/subscriptions.csv
```

Add one subscription from a YouTube URL:

```bash
./ytcs.sh --addsub 'https://www.youtube.com/@kurzgesagt'
```

Show CLI help:

```bash
./ytcs.sh --help
```

## Command-line options

- `--help`, `-h`: Show help text.
- `--loud`, `-l`: Print progress and diagnostic output to stderr.
- `--cli`: Enable CLI mode.
- `--kitty`: Relaunch in a dedicated kitty window using `ytcs-kitty.conf`.
- `--refresh`, `-r`: Refresh all cached feeds and rebuild grouped/time caches.
- `--import`, `-i FILE`: Import subscriptions from CSV.
- `--addsub URL`: Add a subscription from a handle URL or `/channel/` URL.
- `--subscription`, `-s`: Browse by channel.
- `--grouped`, `-g`: Browse grouped by channel.
- `--time`, `--chronological`, `-t`, `-c`: Browse in reverse chronological order.

If no arguments are provided, `ytcs.sh` opens an `fzf` multi-select launcher for the main actions.

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
export YTPOT_BASEURL="youtubepot-bgutilhttp:base_url=http://127.0.0.1:8080"
export YTUBE_API_KEY=""
```

Important settings:

- `MAX_CHANNEL_AGE`: Maximum channel age in days for grouped view.
- `MAX_GROUPED_VIDS`: Maximum videos shown per channel in grouped view.
- `watchtop`: Maximum concurrent workers for feed refresh and parsing.
- `YTDLP_COOKIES`: Browser profile source for `yt-dlp` cookies.
- `MARK_AGE`: Enable or disable age markers in lists.
- `GEOMETRY1`, `GEOMETRY2`: `mpv` window geometry options.
- `YTPOT_BASEURL`: Optional extractor args for the BGUtil POTS provider.
- `YTUBE_API_KEY`: Required for resolving handle URLs in `--addsub`.

## Preview behavior

When selecting videos, `fzf` shows:

- the `media:description` from the feed entry
- the feed thumbnail rendered with `timg`, when available

In `--kitty` mode, `fzf` fills the terminal and the preview pane is shown below the list.

## Notes

- Feed data is cached under `${XDG_DATA_HOME:-$HOME/.local/share}/ytcs`.
- `grouped_data.txt` and `time_data.txt` are derived caches.
- `--refresh` refreshes channel XML feeds and rebuilds both derived caches.
- `--time` uses an existing valid `time_data.txt` cache and only rebuilds it when the cache is missing or invalid.
- `--addsub` clears grouped/time caches so they rebuild on next use.
- During playback, watched markers are updated inline in the existing grouped/time cache files.
- The script copies the current video URL to `xclip` and/or `copyq` when available.
- `--addsub` uses the YouTube Data API for handle URLs. If `YTUBE_API_KEY` is not set, the script points to TunePocket's channel ID finder:
  `https://www.tunepocket.com/youtube-channel-id-finder/#channle-id-finder-form`
- Some YouTube channels may not currently expose a working RSS feed even when the channel page itself exists.

## License

MIT
