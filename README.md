# ytcs

`ytcs.sh` fetches YouTube channel feeds, lets you browse them with `fzf`, and plays videos with `mpv` and `yt-dlp`, so you can watch through your normal browser cookies instead of using the YouTube site.

If what you want is "show me my subscriptions, let me search quickly, and play things in `mpv`", that is what this script is for.

[![Video of ytcs in action](https://img.youtube.com/vi/-9A_c_ztEbc/0.jpg)](https://www.youtube.com/watch?v=-9A_c_ztEbc)

## What it does

- Browses videos by channel, grouped by channel, or in reverse chronological order
- Queues multiple videos from grouped and chronological views with `Tab`
- Marks watched videos and shows age indicators in the list
- Previews descriptions and thumbnails in `fzf`
- Imports subscriptions from CSV or adds one directly from a YouTube URL
- Can relaunch into a dedicated kitty window
- Can force kitty graphics in previews without relaunching the whole UI
- Can filter Shorts out of listing views

## Requirements

For normal use you need:

- `mpv`
- `fzf`
- `yt-dlp` or `youtube-dl`
- `curl` or `wget`

Useful extras:

- `xmlstarlet` for faster and more reliable feed parsing
- `timg` for thumbnail previews
- `jq` for `--addsub` when resolving YouTube handles
- `kitty` and `wmctrl` for `--kitty`
- `xclip` and/or `copyq` if you want the current video URL copied to your clipboard

`curl` is the preferred fetcher when both `curl` and `wget` are installed.

## Installation

Clone the repository and make the script executable if needed:

```bash
git clone <repo-url>
cd ytcs
chmod +x ytcs.sh
cp ytcs.env.example ytcs.env
```

Then edit `ytcs.env` if you want to change defaults.

If you create a local `./cache` directory beside the script, `ytcs` will use that. Otherwise it falls back to `${XDG_DATA_HOME:-$HOME/.local/share}/ytcs`.

## Quick start

Play a single video directly:

```bash
./ytcs.sh 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Open the launcher:

```bash
./ytcs.sh
```

Refresh cached feeds:

```bash
./ytcs.sh --refresh
```

Browse in time order:

```bash
./ytcs.sh --time
```

Browse without Shorts:

```bash
./ytcs.sh --time --noshorts
```

Launch the interface inside kitty:

```bash
./ytcs.sh --kitty --time
```

Keep the normal layout, but force kitty graphics in previews:

```bash
./ytcs.sh --fancy --time
```

## Usage

### Playing one video

If you pass a YouTube URL directly, `ytcs` just hands it off to `mpv`. This is the simplest mode:

```bash
./ytcs.sh 'https://www.youtube.com/watch?v=VIDEO_ID'
```

That also updates the local watched cache after playback.

### Browsing subscriptions

There are three main subscription views:

- `--subscription` / `-s`: browse by channel, then choose a video
- `--grouped` / `-g`: browse grouped channel sections
- `--time` / `--chronological` / `-t` / `-c`: browse one reverse-chronological feed

Grouped and chronological views support multi-select queueing with `Tab`.

### Importing subscriptions

Import a CSV export like this:

```bash
./ytcs.sh --import /path/to/subscriptions.csv
```

The CSV should use the usual channel export shape: channel id, URL, channel name, with no trailing comma. The included sample matches the format FreeTube exports.

### Adding one subscription directly

You can add a channel from either a handle URL or a `/channel/...` URL:

```bash
./ytcs.sh --addsub 'https://www.youtube.com/@kurzgesagt'
```

Handle resolution uses the YouTube Data API, so `YTUBE_API_KEY` must be set in `ytcs.env` for `@handle` inputs.

## Command line options

- `--help`, `-h`: show help text
- `--loud`, `-l`: print progress and diagnostic output to stderr
- `--cli`: enable CLI mode
- `--kitty`: relaunch in a dedicated kitty window using `ytcs-kitty.conf`
- `--fancy`, `-f`: force kitty graphics in previews without relaunching into kitty mode
- `--refresh`, `-r`: refresh cached feeds and rebuild grouped/time caches
- `--noshorts`, `-n`: exclude entries marked as Shorts from listing views
- `--import`, `-i FILE`: import subscriptions from CSV
- `--addsub URL`: add one subscription from a YouTube handle URL or `/channel/` URL
- `--subscription`, `-s`: browse videos by channel
- `--grouped`, `-g`: browse videos grouped by channel
- `--time`, `--chronological`, `-t`, `-c`: browse videos in reverse chronological order

If you run `ytcs.sh` with no arguments, it opens an `fzf` launcher for the main actions.

## fzf behavior

- `Enter`: run the selected action or play the selected video
- `Esc`: cancel the current view
- `Tab`: queue multiple videos in grouped and chronological views
- typing filters the list

Video previews can show:

- the feed entry description
- the cached thumbnail, if `timg` is installed

In `--kitty` mode, the UI is relaunched inside kitty and the preview pane moves below the list.

In `--fancy` mode, the main UI stays in the normal layout, but preview rendering still gets kitty-style behavior. This can be handy, but it is also the mode most likely to behave oddly in `tmux`, nested terminals, or terminals that only partially support kitty graphics.

## Configuration

The defaults from `ytcs.env.example` are:

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

The settings you are most likely to care about are:

- `MAX_CHANNEL_AGE`: maximum channel age in days for grouped view
- `MAX_GROUPED_VIDS`: maximum videos shown per channel in grouped view
- `watchtop`: maximum concurrent workers for refresh and parsing; if unset, `ytcs` uses up to your CPU core count
- `YTDLP_COOKIES`: browser profile source for `yt-dlp`
- `MARK_AGE`: enable or disable age markers in lists
- `GEOMETRY1`, `GEOMETRY2`: `mpv` geometry options
- `YTPOT_BASEURL`: optional extractor args for the BGUtil POTS provider
- `YTUBE_API_KEY`: required for resolving YouTube handles in `--addsub`

## Notes

- Feed data is cached either in local `./cache` or under `${XDG_DATA_HOME:-$HOME/.local/share}/ytcs`.
- `grouped_data.txt`, `time_data.txt`, and `parsed_time/` are derived caches.
- `--refresh` refreshes channel XML feeds and rebuilds grouped and chronological caches.
- `--time` reuses an existing valid time cache and only rebuilds it when needed.
- Feed refresh preserves the old cached XML if a fetched response is invalid or looks like an error page.
- `--addsub` clears grouped and time caches so they rebuild on next use.
- Playback still passes `--mark-watched` to `yt-dlp`, and `ytcs` also records local watched state in `watched_files.txt` after the playback pipeline exits.
- During playback, `ytcs` updates local watched markers inline in `grouped_data.txt` and `time_data.txt` when those cache files exist.
- Cache-walking code skips derived directories such as `parsed_time/` and `thumbnails/`, so channel browsing should not emit stray `grep: ... Is a directory` warnings.
- Some YouTube channels simply do not expose a usable RSS feed even when the channel page itself exists.

This script is for personal use. Make sure your usage complies with YouTube's terms and with the wishes of the creators whose videos you are watching.

## License

MIT
