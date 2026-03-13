#!/bin/bash


##############################################################################
#
#  ytcs -- to scroll through and view youtube videos
#  through RSS feeds and yt-dlp and mpv
#
#  (c) Steven Saus 2026
#  Licensed under the MIT license
#
##############################################################################

# defaults
MAX_CHANNEL_AGE=182
MAX_GROUPED_VIDS=10
YTDLP_COOKIES="firefox"
MARK_AGE="TRUE"
GEOMETRY1="1366x768+50%+50%"
GEOMETRY2="1366x768"
CLIMODE=0
KITTYMODE=0
REFRESHED_THIS_RUN=0
watchtop=""

SCRIPT_DIR="$( cd "$(dirname $(readlink -f "${0}"))" ; pwd -P )"
SCRIPT_PATH="$(readlink -f "${0}")"

# Overwrite defaults via env
if [ -f "${SCRIPT_DIR}/ytcs.env" ];then
    source "${SCRIPT_DIR}/ytcs.env"
fi

if [ -z "${XDG_DATA_HOME}" ];then
    export XDG_DATA_HOME="${HOME}/.local/share"
    export XDG_CONFIG_HOME="${HOME}/.config"
fi

CACHEDIR="${XDG_DATA_HOME}/ytcs"
if [ ! -d "${CACHEDIR}" ];then
    mkdir -p "${CACHEDIR}"
fi
PARSED_TIME_DIR="${CACHEDIR}/parsed_time"
if [ ! -d "${PARSED_TIME_DIR}" ];then
    mkdir -p "${PARSED_TIME_DIR}"
fi
wget_bin=$(which wget)
curl_bin=$(which curl)
mpv_bin=$(which mpv)
grep_bin=$(which grep)
timg_bin=$(which timg)
xmlstarlet_bin=$(which xmlstarlet)
jq_bin=$(which jq)
kitty_bin=$(which kitty)
wmctrl_bin=$(which wmctrl)
ytube_bin=$(which youtube-dl)
dlp=$(which yt-dlp)
if [ "$dlp" != "" ];then
    ytube_bin="${dlp}"
fi

# Some error checking so you don't make more spawns than cores
if [ "$watchtop" == "" ];then
    if [ -f $(which nproc) ];then
        watchtop=$(nproc)
    else
        watchtop=1
    fi
else
    if [ -f $(which nproc) ];then
        if [ $watchtop -gt $(nproc) ];then
            watchtop=$(nproc)
        fi
    else
        watchtop=1
    fi
fi

function loud() {
##############################################################################
# loud outputs on stderr
##############################################################################
    if [ $LOUD -eq 1 ];then
        echo "$@" 1>&2
    fi
}

fzf_select() {
##############################################################################
# fzf_select wraps common fzf options used throughout menu selection
##############################################################################
    local prompt="$1"
    local selector_height="100%"

    if [ "${KITTYMODE}" == "1" ];then
        selector_height="100%"
    fi

    fzf --prompt="${prompt}> " --height="${selector_height}" --layout=reverse --border --header="$(selector_help)"
}

fzf_video_select() {
##############################################################################
# fzf_video_select adds a preview pane for individual video entries
##############################################################################
    local prompt="$1"
    local selector_height="100%"
    local preview_window="right,60%,wrap"

    if [ "${KITTYMODE}" == "1" ];then
        selector_height="100%"
        preview_window="down,55%,wrap"
    fi

    fzf \
        --prompt="${prompt}> " \
        --height="${selector_height}" \
        --layout=reverse \
        --border \
        --with-nth=1,2 \
        --delimiter='|' \
        --header="$(selector_help)" \
        --preview="${SCRIPT_PATH} --preview-item {}" \
        --preview-window="${preview_window}"
}

selector_help() {
##############################################################################
# selector_help prints the shared fzf key help shown in menu headers
##############################################################################
    printf "⏎ picks | Esc cancels | Type to filter | ! to antifilter | ↑↓ moves"
}

find_channel_file_for_video() {
##############################################################################
# find_channel_file_for_video locates the cached channel XML for a video id
##############################################################################
    local video_id="$1"
    local file

    for file in "${CACHEDIR}"/*; do
        [[ ! -f "${file}" ]] && continue
        [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
        [[ "$(basename "$file")" == "grouped_data.txt" ]] && continue
        [[ "$(basename "$file")" == "time_data.txt" ]] && continue
        [[ "$(basename "$file")" == "thumbnails" ]] && continue
        if grep -q "<yt:videoId>${video_id}</yt:videoId>" "${file}" 2>/dev/null; then
            printf "%s\n" "${file}"
            return 0
        fi
    done

    return 1
}

cache_thumbnail() {
##############################################################################
# cache_thumbnail downloads a thumbnail once and reuses it for preview
##############################################################################
    local video_id="$1"
    local thumbnail_url="$2"
    local thumb_dir="${CACHEDIR}/thumbnails"
    local thumb_file="${thumb_dir}/${video_id}.img"

    [ -z "${thumbnail_url}" ] && return 1

    mkdir -p "${thumb_dir}"
    if [ ! -s "${thumb_file}" ];then
        if [ -n "${curl_bin}" ];then
            "${curl_bin}" -fsSL "${thumbnail_url}" -o "${thumb_file}" 2>/dev/null || return 1
        elif [ -n "${wget_bin}" ];then
            "${wget_bin}" -q "${thumbnail_url}" -O "${thumb_file}" || return 1
        else
            return 1
        fi
    fi

    printf "%s\n" "${thumb_file}"
}

render_thumbnail_preview() {
##############################################################################
# render_thumbnail_preview displays the thumbnail in the fzf preview pane
##############################################################################
    local thumb_file="$1"
    local preview_cols="${FZF_PREVIEW_COLUMNS:-60}"
    local preview_lines="${FZF_PREVIEW_LINES:-30}"
    local image_lines=$(( preview_lines / 2 ))

    [ -z "${thumb_file}" ] && return 1
    [ ! -f "${thumb_file}" ] && return 1
    [ -z "${timg_bin}" ] && return 1
    [ "${image_lines}" -lt 8 ] && image_lines=8

    "${timg_bin}" -g "${preview_cols}x${image_lines}" "${thumb_file}" 2>/dev/null
}

preview_video_entry() {
##############################################################################
# preview_video_entry renders the metadata preview for a selected video row
##############################################################################
    local raw_line="$1"
    local selected_line video_id channel_file preview_width
    local title published channel_title description thumbnail_url thumb_file

    selected_line=$(printf "%s\n" "${raw_line}" | sed 's/\x1B\[[0-9;]*[[:alpha:]]//g')
    preview_width="${FZF_PREVIEW_COLUMNS:-80}"

    if [[ -z "${selected_line}" || "${selected_line}" == "§ Exit" ]];then
        printf "Exit this view.\n"
        return 0
    fi

    if [[ "${selected_line}" == §* ]];then
        printf "%s\n" "${selected_line}"
        printf "\nSelect a video entry to preview its details.\n"
        return 0
    fi

    video_id=$(printf "%s\n" "${selected_line}" | awk -F'|' '{print $NF}' | xargs)
    if [ -z "${video_id}" ];then
        printf "No video id found for this entry.\n"
        return 1
    fi

    if [ -z "${xmlstarlet_bin}" ];then
        printf "xmlstarlet is required for video previews.\n"
        return 1
    fi

    channel_file=$(find_channel_file_for_video "${video_id}")
    if [ -z "${channel_file}" ];then
        printf "Unable to locate cached feed entry for %s.\n" "${video_id}"
        return 1
    fi

    channel_title=$("${xmlstarlet_bin}" sel -T \
        -N 'atom=http://www.w3.org/2005/Atom' \
        -t -v '/atom:feed/atom:title' -n "${channel_file}" 2>/dev/null | head -n 1)

    title=$("${xmlstarlet_bin}" sel -T \
        -N 'atom=http://www.w3.org/2005/Atom' \
        -N 'media=http://search.yahoo.com/mrss/' \
        -N 'yt=http://www.youtube.com/xml/schemas/2015' \
        -t -m "//atom:entry[yt:videoId='${video_id}']" \
        -v "normalize-space(atom:title)" -n "${channel_file}" 2>/dev/null)
    published=$("${xmlstarlet_bin}" sel -T \
        -N 'atom=http://www.w3.org/2005/Atom' \
        -N 'media=http://search.yahoo.com/mrss/' \
        -N 'yt=http://www.youtube.com/xml/schemas/2015' \
        -t -m "//atom:entry[yt:videoId='${video_id}']" \
        -v "normalize-space(atom:published)" -n "${channel_file}" 2>/dev/null)
    description=$("${xmlstarlet_bin}" sel -T \
        -N 'atom=http://www.w3.org/2005/Atom' \
        -N 'media=http://search.yahoo.com/mrss/' \
        -N 'yt=http://www.youtube.com/xml/schemas/2015' \
        -t -m "//atom:entry[yt:videoId='${video_id}']" \
        -v "normalize-space(media:group/media:description)" -n "${channel_file}" 2>/dev/null)
    thumbnail_url=$("${xmlstarlet_bin}" sel -T \
        -N 'atom=http://www.w3.org/2005/Atom' \
        -N 'media=http://search.yahoo.com/mrss/' \
        -N 'yt=http://www.youtube.com/xml/schemas/2015' \
        -t -m "//atom:entry[yt:videoId='${video_id}']" \
        -v "normalize-space(media:group/media:thumbnail[1]/@url)" -n "${channel_file}" 2>/dev/null)

    if [ -n "${thumbnail_url}" ];then
        thumb_file=$(cache_thumbnail "${video_id}" "${thumbnail_url}")
        render_thumbnail_preview "${thumb_file}"
        printf "\n"
    fi

    printf "Title: %s\n" "${title}"
    printf "Channel: %s\n" "${channel_title}"
    printf "Published: %s\n" "${published}"
    printf "Video: https://www.youtube.com/watch?v=%s\n" "${video_id}"
    if [ -n "${thumbnail_url}" ];then
        printf "Thumbnail: %s\n" "${thumbnail_url}"
    fi
    printf "\nDescription:\n"
    if [ -n "${description}" ];then
        printf "%s\n" "${description}" | fold -s -w "${preview_width}"
    else
        printf "No media:description found for this entry.\n"
    fi
}

interactive_menu() {
##############################################################################
# interactive_menu builds switches from an fzf multi-select launcher
##############################################################################
    local choices selected line option import_file addsub_url browse_count
    local -a selected_args=()
    MENU_ARGS=()

    choices=$(
        cat <<'EOF'
--loud|Extra feedback on stderr
--cli|CLI mode
--refresh|Refresh cached subscription data
--subscription|Browse by subscription
--grouped|Browse grouped by subscription
--time|Browse in chronological order
--help|Show help and exit
--import|Import subscriptions from CSV
--addsub|Add a subscription from a YouTube URL
EOF
    )

    selected=$(printf "%s\n" "${choices}" | fzf \
        --multi \
        --prompt="ytcs> " \
        --height="$([ "${KITTYMODE}" == "1" ] && printf "100%%" || printf "50%%")" \
        --layout=reverse \
        --border \
        --header="Tab mark | Enter run | ${selector_help}" \
        --delimiter='|' \
        --with-nth=1,2)

    [ -z "${selected}" ] && exit 0

    browse_count=0
    while IFS= read -r line; do
        option=$(printf "%s\n" "${line}" | awk -F'|' '{print $1}')
        case "${option}" in
            --subscription|--grouped|--time)
                browse_count=$((browse_count + 1))
                ;;
        esac
        selected_args+=("${option}")
    done <<< "${selected}"

    if [ "${browse_count}" -gt 1 ];then
        echo "Select only one of --subscription, --grouped, or --time." 1>&2
        exit 95
    fi

    for option in "${selected_args[@]}"; do
        if [ "${option}" == "--import" ];then
            read -r -p "CSV path for --import: " import_file
            if [ -z "${import_file}" ];then
                echo "--import requires a CSV path." 1>&2
                exit 96
            fi
            if [ ! -f "${import_file}" ];then
                echo "Import file not found: ${import_file}" 1>&2
                exit 96
            fi
        fi
        if [ "${option}" == "--addsub" ];then
            read -r -p "YouTube URL for --addsub: " addsub_url
            if [ -z "${addsub_url}" ];then
                echo "--addsub requires a YouTube URL." 1>&2
                exit 96
            fi
        fi
    done

    MENU_ARGS=("${selected_args[@]}")
    if printf "%s\n" "${selected_args[@]}" | grep -Eq '^--(import|addsub)$'; then
        local -a expanded_args=()
        for option in "${selected_args[@]}"; do
            expanded_args+=("${option}")
            if [ "${option}" == "--import" ];then
                expanded_args+=("${import_file}")
            fi
            if [ "${option}" == "--addsub" ];then
                expanded_args+=("${addsub_url}")
            fi
        done
        MENU_ARGS=("${expanded_args[@]}")
    fi
}

position_kitty_window() {
##############################################################################
# position_kitty_window attempts to move the kitty window to the left edge
##############################################################################
    local match_class="ytcs-kitty.ytcs-kitty"
    local attempt

    [ -z "${wmctrl_bin}" ] && return 0

    (
        for attempt in $(seq 1 40); do
            sleep 0.15
            "${wmctrl_bin}" -x -r "${match_class}" -e 0,0,0,800,800 >/dev/null 2>&1 && exit 0
        done
        exit 0
    ) >/dev/null 2>&1 &
}

launch_in_kitty() {
##############################################################################
# launch_in_kitty runs ytcs in a dedicated kitty window with repo config
##############################################################################
    local kitty_conf="${SCRIPT_DIR}/ytcs-kitty.conf"
    local quoted_dir quoted_cmd
    local -a forwarded_args=("${@}")
    local -a launch_args=("${SCRIPT_PATH}" "--kitty-launched" "${forwarded_args[@]}")

    if [ -z "${kitty_bin}" ];then
        echo "kitty is required for --kitty mode." 1>&2
        exit 94
    fi

    printf -v quoted_dir '%q' "${SCRIPT_DIR}"
    printf -v quoted_cmd '%q ' "${launch_args[@]}"

    "${kitty_bin}" \
        --class ytcs-kitty \
        --name ytcs-kitty \
        --title ytcs \
        --config "${kitty_conf}" \
        --directory "${SCRIPT_DIR}" \
        --detach \
        bash -lc "cd ${quoted_dir}; exec ${quoted_cmd}"

    position_kitty_window
    exit 0
}

preprocess_args() {
##############################################################################
# preprocess_args handles relaunch into kitty and strips internal switches
##############################################################################
    local arg
    local launch_kitty=0
    PREPROCESSED_ARGS=()

    for arg in "$@"; do
        case "${arg}" in
            --kitty)
                launch_kitty=1
                ;;
            --kitty-launched)
                KITTYMODE=1
                ;;
            *)
                PREPROCESSED_ARGS+=("${arg}")
                ;;
        esac
    done

    if [ "${launch_kitty}" == "1" ] && [ "${KITTYMODE}" != "1" ];then
        launch_in_kitty "${PREPROCESSED_ARGS[@]}"
    fi
}

display_help(){
##############################################################################
# Show the Help
##############################################################################
    cat <<'EOF'
Usage:
  ytcs.sh [URL]
  ytcs.sh [--loud] [--cli] [--kitty] [--refresh]
          [--import FILE] [--addsub URL]
          [--subscription | --grouped | --time]

Options:
  --help, -h
      Show this help text.

  --loud, -l
      Print progress and diagnostic messages to stderr.

  --cli
      Enable CLI mode.

  --kitty
      Relaunch in a dedicated kitty window using the bundled config.

  --refresh, -r
      Refresh all cached subscription feeds and rebuild grouped/time caches.

  --import, -i FILE
      Import subscriptions from a CSV file in channel-id export format.

  --addsub URL
      Add one subscription from a YouTube handle URL or /channel/ URL.

Views:
  --subscription, -s
      Browse videos by channel.

  --grouped, -g
      Browse videos grouped by channel.

  --time, --chronological, -t, -c
      Browse videos in reverse chronological order.

Behavior:
  If no arguments are provided, ytcs opens an fzf multi-select launcher.
  --time uses an existing valid time cache and only rebuilds it when missing
  or invalid.
  fzf controls: Enter select, Esc cancel, type to filter, Ctrl-J/K move.
EOF
    exit
}

fetch_subscription_feed() {
##############################################################################
# fetch_subscription_feed downloads a channel RSS feed into the cache
##############################################################################
    local channel_id="$1"
    local output_file="${CACHEDIR}/${channel_id}"
    local temp_file="${output_file}.tmp.$$"
    local feed_url="https://www.youtube.com/feeds/videos.xml?channel_id=${channel_id}"
    local browser_ua="Mozilla/5.0"
    local accept_header="Accept: application/rss+xml,application/xml,text/xml;q=0.9,*/*;q=0.8"

    if [ -n "${curl_bin}" ];then
        "${curl_bin}" -fsSL \
            -A "${browser_ua}" \
            -H "${accept_header}" \
            "${feed_url}" -o "${temp_file}" || {
            rm -f "${temp_file}"
            return 1
        }
    elif [ -n "${wget_bin}" ];then
        "${wget_bin}" -q \
            --user-agent="${browser_ua}" \
            --header="${accept_header}" \
            "${feed_url}" -O "${temp_file}" || {
            rm -f "${temp_file}"
            return 1
        }
    else
        return 1
    fi

    if [ ! -s "${temp_file}" ];then
        rm -f "${temp_file}"
        return 1
    fi

    mv "${temp_file}" "${output_file}"
    return 0
}

extract_channel_ref() {
##############################################################################
# extract_channel_ref parses either a handle URL or direct /channel/ URL
##############################################################################
    local input="$1"
    local cleaned handle channel_id

    cleaned="${input%%\?*}"
    cleaned="${cleaned%%\#*}"
    cleaned="${cleaned%/}"

    if [[ "${cleaned}" =~ /channel/([A-Za-z0-9_-]+)$ ]];then
        channel_id="${BASH_REMATCH[1]}"
        printf "id:%s\n" "${channel_id}"
        return 0
    fi

    if [[ "${cleaned}" =~ /@([^/]+) ]];then
        handle="${BASH_REMATCH[1]}"
        printf "handle:%s\n" "${handle}"
        return 0
    fi

    if [[ "${cleaned}" =~ ^@?([A-Za-z0-9._-]+)$ ]];then
        handle="${BASH_REMATCH[1]}"
        printf "handle:%s\n" "${handle}"
        return 0
    fi

    return 1
}

channel_id_from_handle() {
##############################################################################
# channel_id_from_handle resolves a YouTube handle to a channel id
##############################################################################
    local handle="$1"
    local api_url response channel_id

    if [ -z "${YTUBE_API_KEY}" ];then
        echo "YTUBE_API_KEY is not set in ytcs.env." 1>&2
        echo "Use https://www.tunepocket.com/youtube-channel-id-finder/#channle-id-finder-form to find the channel ID manually." 1>&2
        return 1
    fi

    if [ -z "${curl_bin}" ] || [ -z "${jq_bin}" ];then
        echo "curl and jq are required for --addsub handle lookup." 1>&2
        return 1
    fi

    handle="${handle#@}"
    api_url="https://www.googleapis.com/youtube/v3/channels?part=id&forHandle=${handle}&key=${YTUBE_API_KEY}"
    response=$("${curl_bin}" -fsS "${api_url}" 2>/dev/null) || return 1
    channel_id=$(printf "%s\n" "${response}" | "${jq_bin}" -r '.items[0].id // empty')

    [ -n "${channel_id}" ] || return 1
    printf "%s\n" "${channel_id}"
}

add_subscription_from_url() {
##############################################################################
# add_subscription_from_url resolves a YouTube URL to a channel feed cache file
##############################################################################
    local url="$1"
    local channel_ref channel_id channel_title

    if [ -z "${url}" ];then
        echo "--addsub requires a YouTube URL." 1>&2
        return 96
    fi

    channel_ref=$(extract_channel_ref "${url}") || {
        echo "Unsupported YouTube URL for --addsub: ${url}" 1>&2
        echo "Use a handle URL like https://www.youtube.com/@kurzgesagt or a /channel/ URL." 1>&2
        return 96
    }

    case "${channel_ref}" in
        id:*)
            channel_id="${channel_ref#id:}"
            ;;
        handle:*)
            channel_id=$(channel_id_from_handle "${channel_ref#handle:}") || {
                echo "Unable to resolve a channel ID from: ${url}" 1>&2
                return 97
            }
            ;;
    esac

    loud "[info] Adding subscription ${channel_id}"
    fetch_subscription_feed "${channel_id}" || {
        echo "Failed to fetch channel feed for ${channel_id}." 1>&2
        return 98
    }

    if [ -n "${xmlstarlet_bin}" ];then
        channel_title=$("${xmlstarlet_bin}" sel -T \
            -N 'atom=http://www.w3.org/2005/Atom' \
            -t -v '/atom:feed/atom:title' -n "${CACHEDIR}/${channel_id}" 2>/dev/null | head -n 1)
    else
        channel_title=$(grep -m 1 "<title>" "${CACHEDIR}/${channel_id}" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
    fi

    if [ -n "${channel_title}" ];then
        echo "Added subscription: ${channel_title} (${channel_id})"
    else
        echo "Added subscription: ${channel_id}"
    fi

    rm -f "${CACHEDIR}/grouped_data.txt" "${CACHEDIR}/time_data.txt"
    loud "[info] Cleared grouped and chronological caches; they will rebuild on next use."
    return 0
}

import_subscriptions()
{
    if [ -z "$SUBSCRIPTIONFILE" ];then
        SUBSCRIPTIONFILE="$1"
    fi
    watchcount=0
    while read line; do
        if [ $watchcount -gt $watchtop ];then
            wait
            watchcount=0
        fi
        watchcount=$(( watchcount + 1 ))
        (
        id=$(echo "$line"|awk -F ',' '{print $1}')
        #url=$(echo "$line"|awk -F ',' '{print $2}')
        #name=$(echo "$line"|awk -F ',' '{print $3}')
        if [[ "$id" != "Channel Id" ]];then
            fetch_subscription_feed "${id}"
        fi
        ) &
    done < "${SUBSCRIPTIONFILE}"
    exit
}

refresh_subscriptions() {
    REFRESHED_THIS_RUN=1
    loud "[info] Refreshing subscriptions"
    watchcount=0
    for file in "$CACHEDIR"/*; do
        [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
        [[ "$(basename "$file")" == "grouped_data.txt" ]] && continue
        [[ "$(basename "$file")" == "time_data.txt" ]] && continue
        if [ $watchcount -gt $watchtop ];then
            wait
            watchcount=0
        fi
        watchcount=$(( watchcount + 1 ))
        (
        id=$(basename "${file}")
        if [ -f "$file" ];then
            if [ -n "${xmlstarlet_bin}" ];then
                feed_name=$("${xmlstarlet_bin}" sel -T \
                    -N 'atom=http://www.w3.org/2005/Atom' \
                    -t -v '/atom:feed/atom:title' -n "${file}" 2>/dev/null | head -n 1)
            else
                feed_name=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
            fi
            [ -z "${feed_name}" ] && feed_name="${id}"

            loud "[info] Refreshing feed: ${feed_name}"
            if fetch_subscription_feed "${id}"; then
                loud "[info] Refreshed feed: ${feed_name} (ok)"
            else
                loud "[warn] Refreshed feed: ${feed_name} (failed)"
            fi
        fi
        id="" ) &
    done
    wait
    loud "[info] Refreshing grouped data"
    parse_subscriptions g progress > "${CACHEDIR}/grouped_data.txt"
    loud "[info] Grouped data refresh complete"
    loud "[info] Refreshing chronological data"
    parse_subscriptions c progress > "${CACHEDIR}/time_data.txt"
    loud "[info] Chronological data refresh complete"
    loud "[info] Refresh complete"
}

is_file_newer_than_any_xml() {
    local dir="$1"
    local file="$2"

    # Make sure both directory and file exist
    [[ ! -d "$dir" || ! -f "$file" ]] && return 1

    local file_ts
    file_ts=$(stat -c %Y "$file")
    # Loop through files in the directory

    for file in "${dir}"/*; do
        [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
        [[ "$(basename "$file")" == "grouped_data.txt" ]] && continue
        [[ "$(basename "$file")" == "time_data.txt" ]] && continue
        [[ "$(basename "$file")" == "thumbnails" ]] && continue
        [[ "$(basename "$file")" == "parsed_time" ]] && continue
        [[ ! -f "$file" ]] && continue
        xml_ts=$(stat -c %Y "$file")
        if (( file_ts > xml_ts )); then
            return 0  # the file is newer than at least one .xml
        fi
    done

    return 1  # file is not newer than any .xml
}

cache_uses_epoch() {
    local file="$1"
    local epoch_field

    [ ! -f "${file}" ] && return 1

    epoch_field=$(awk -F'|' '
        /^[[:space:]]*$/ { next }
        /^§/ { next }
        {
            gsub(/^[ \t]+|[ \t]+$/, "", $3)
            print $3
            exit
        }
    ' "${file}")

    [[ "${epoch_field}" =~ ^[0-9]+$ ]]
}

rebuild_time_cache_sync() {
##############################################################################
# rebuild_time_cache_sync rebuilds chronological cache immediately
##############################################################################
    local temp_file="${CACHEDIR}/time_data.txt.tmp.$$"
    parse_subscriptions c > "${temp_file}" && mv "${temp_file}" "${CACHEDIR}/time_data.txt"
}

most_recent_age() {
    local data="$1"
    local latest_ts=0

    # Loop over each line
    while IFS= read -r line; do
        ts=$(echo "$line" | awk -F '|' '{print $2}' | xargs)
        [[ -z "$ts" ]] && continue

        # Keep the latest (most recent) timestamp
        if (( ts > latest_ts )); then
            latest_ts=$ts
        fi
    done <<< "$data"

    # If no valid timestamp found
    if (( latest_ts == 0 )); then
        echo "N/A,N/A"
        return 1
    fi

    # Calculate age in days and weeks
    now_ts=$(date +%s)
    seconds_old=$(( now_ts - latest_ts ))
    days_old=$(( seconds_old / 86400 ))
    echo "${days_old}"
}

add_human_date() {
    while IFS= read -r line; do
        epoch=$(echo "$line" | awk -F '|' '{print $2}' | xargs)
        if [[ "${epoch}" =~ ^[0-9]+$ ]]; then
            title=$(echo "$line" | awk -F '|' '{print $1}')
            id=$(echo "$line" | awk -F '|' '{print $3}' | xargs)
            human=$(date -d "@${epoch}" "+%-d %B %Y")
            printf "%s | %s | %s | %s\n" "${title}" "${human}" "${epoch}" "${id}"
        else
            echo "$line"
        fi
    done
}

mark_if_watched() {
    local data="$@"
    if [ -f "${CACHEDIR}"/watched_files.txt ];then
        # Filter and prepend § Exit
        {
            echo "§ Exit"
            while IFS= read -r line; do
                [[ "${line}" == "" ]] && continue
                if [[ $line == *"📺"* ]];then
                    printf "\n%s\n" "${line}"
                else
                    id=$(echo "${line}" | awk -F'|' '{print $NF}' )  # Extract the string after the last "| "
                    command=$(printf "%s -c -- \"%s\" \"%s\"" "${grep_bin}" "${id}" "${CACHEDIR}/watched_files.txt")
                    count=$(eval "${command}")
                    if [ "$count" == "" ];then
                        count=0
                    fi
                    if [ $count -ge 1 ]; then
                        printf "👀 %s\n" "${line}" | mark_age | add_human_date
                    else
                        printf "%s\n" "${line}" | mark_age | add_human_date
                    fi
                fi
            done <<< "$(echo "${data}")"
        }
    else
        { echo "§ Exit"; echo -e "$data"; }
    fi

}

mark_age() {
    local one_week_ago two_weeks_ago three_weeks_ago four_weeks_ago five_weeks_ago \
      six_weeks_ago seven_weeks_ago eight_weeks_ago nine_weeks_ago ten_weeks_ago \
      line line_ts

    one_week_ago=$(date -d '7 days ago' +%s)
    two_weeks_ago=$(date -d '14 days ago' +%s)
    three_weeks_ago=$(date -d '21 days ago' +%s)
    four_weeks_ago=$(date -d '28 days ago' +%s)
    five_weeks_ago=$(date -d '35 days ago' +%s)
    six_weeks_ago=$(date -d '42 days ago' +%s)
    seven_weeks_ago=$(date -d '49 days ago' +%s)
    #eight_weeks_ago=$(date -d '56 days ago' +%s)
    #nine_weeks_ago=$(date -d '63 days ago' +%s)
    #ten_weeks_ago=$(date -d '70 days ago' +%s)

    while IFS= read -r line; do
        if [ "${MARK_AGE}" == "TRUE" ];then
            line_ts=$(echo "$line" | awk -F '|' '{print $2}' | xargs)
            if [[ -z "$line_ts" ]]; then
                echo "$line"
                continue
            fi

            if (( line_ts < seven_weeks_ago )); then
                echo "▁ $line"
            elif (( line_ts < six_weeks_ago )); then
                echo "▂ $line"
            elif (( line_ts < five_weeks_ago )); then
                echo "▃ $line"
            elif (( line_ts < four_weeks_ago )); then
                echo "▄ $line"
            elif (( line_ts < three_weeks_ago )); then
                echo "▅ $line"
            elif (( line_ts < two_weeks_ago )); then
                echo "▆ $line"
            elif (( line_ts < one_week_ago )); then
                echo "▇ $line"
            else
                echo "█ $line"
            fi
        else
            echo " $line"
        fi
    done
}

convert_feed_dates_to_epoch() {
##############################################################################
# convert_feed_dates_to_epoch replaces the hidden published field with epoch
##############################################################################
    local line title published video_id is_short epoch

    while IFS= read -r line; do
        title=$(echo "$line" | awk -F '|' '{print $1}')
        published=$(echo "$line" | awk -F '|' '{print $2}' | xargs)
        video_id=$(echo "$line" | awk -F '|' '{print $3}' | xargs)
        is_short=$(echo "$line" | awk -F '|' '{print $4}' | xargs)
        epoch=$(date -d "$published" +%s 2>/dev/null)
        [ -z "${epoch}" ] && continue
        if [ "${is_short}" = "1" ];then
            title="[s] ${title}"
        fi
        printf "%s | %s | %s\n" "${title}" "${epoch}" "${video_id}"
    done
}

progress_bar() {
##############################################################################
# progress_bar prints a simple textual progress bar
##############################################################################
    local current="$1"
    local total="$2"
    local width=20
    local filled=0
    local empty=0
    local bar=""
    local i

    if [ "${total}" -gt 0 ];then
        filled=$(( current * width / total ))
    fi
    empty=$(( width - filled ))

    for (( i=0; i<filled; i++ )); do
        bar="${bar}#"
    done
    for (( i=0; i<empty; i++ )); do
        bar="${bar}-"
    done
    printf "[%s]" "${bar}"
}

log_parse_progress() {
##############################################################################
# log_parse_progress emits per-feed parse progress during loud refreshes
##############################################################################
    local phase="$1"
    local current="$2"
    local total="$3"
    local name="$4"

    loud "[info] ${phase} $(progress_bar "${current}" "${total}") ${current}/${total}: ${name}"
}

is_source_newer_than_target() {
##############################################################################
# is_source_newer_than_target checks whether a source file is newer than target
##############################################################################
    local source_file="$1"
    local target_file="$2"

    [ ! -f "${source_file}" ] && return 1
    [ ! -f "${target_file}" ] && return 0
    [ "${source_file}" -nt "${target_file}" ]
}

extract_feed_entries() {
##############################################################################
# extract_feed_entries outputs title|published|video_id|is_short for a feed
##############################################################################
    local file="$1"
    local max_entries="$2"

    [ ! -s "${file}" ] && return 0

    if [ -n "${xmlstarlet_bin}" ];then
        "${xmlstarlet_bin}" sel -T \
            -N 'atom=http://www.w3.org/2005/Atom' \
            -N 'yt=http://www.youtube.com/xml/schemas/2015' \
            -t \
            -m '//atom:entry' \
            -v 'concat(translate(normalize-space(atom:title),"|",""), " | ", normalize-space(atom:published), " | ", normalize-space(yt:videoId), " | ", substring("1", 1, contains(atom:link[@rel="alternate"]/@href, "/shorts/")))' \
            -n "${file}" 2>/dev/null \
            | awk -v max="${max_entries}" 'NR<=max { gsub(/"/,"‘"); gsub(/&/,"and"); print }'
    else
        awk -v max="${max_entries}" '
            BEGIN {
                RS="</entry>"
                count=0
            }
            count >= max { exit }
            {
                title=""
                published=""
                video_id=""
                is_short="0"

                if (match($0, /<title[^>]*>([^<]+)/, m)) title=m[1]
                if (match($0, /<published[^>]*>([^<]+)/, m)) published=m[1]
                if (match($0, /<yt:videoId[^>]*>([^<]+)/, m)) video_id=m[1]
                if ($0 ~ /<link[^>]*rel="alternate"[^>]*href="https:[^"]*\/shorts\//) is_short="1"

                gsub(/\|/, "", title)
                gsub(/&quot;/, "‘", title)
                gsub(/&amp;/, "and", title)

                if (title != "" && published != "" && video_id != "") {
                    printf "%s | %s | %s | %s\n", title, published, video_id, is_short
                    count++
                }
            }
        ' "${file}"
    fi
}

build_time_channel_cache() {
##############################################################################
# build_time_channel_cache stores parsed chronological data for one channel
##############################################################################
    local file="$1"
    local channel_id
    local chantitle
    local parsed_file
    local temp_file

    channel_id=$(basename "${file}")
    parsed_file="${PARSED_TIME_DIR}/${channel_id}.txt"

    if ! is_source_newer_than_target "${file}" "${parsed_file}"; then
        printf "%s\n" "${parsed_file}"
        return 0
    fi

    chantitle=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
    temp_file="${parsed_file}.tmp.$$"

    extract_feed_entries "${file}" 999999 \
        | convert_feed_dates_to_epoch \
        | sed "s/^/\[${chantitle}\] /" > "${temp_file}"

    mv "${temp_file}" "${parsed_file}"
    printf "%s\n" "${parsed_file}"
}

parse_subscriptions(){
    trap '' PIPE
    local phase="$2"
    local show_progress=0
    local -a feed_files=()
    local total_files=0
    local progress_index=0
    local file chantitle chanid thischanneldata thischannelage thischanneltitle thisfiledata parsed_file

    shopt -s nullglob
    for file in "${CACHEDIR}"/*; do
        [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
        [[ "$(basename "$file")" == "grouped_data.txt" ]] && continue
        [[ "$(basename "$file")" == "time_data.txt" ]] && continue
        [[ "$(basename "$file")" == "thumbnails" ]] && continue
        [[ "$(basename "$file")" == "parsed_time" ]] && continue
        [[ ! -f "$file" ]] && continue
        feed_files+=("${file}")
    done
    total_files=${#feed_files[@]}

    if [ "${phase}" == "progress" ];then
        show_progress=1
    fi

    allfiledata=""
    if [ "$1" = "g" ];then
        # this is per subscription, latest MAX_GROUPED_VIDS
        TEMPFILE=$(mktemp)
        for file in "${feed_files[@]}"; do
            if [ -f "$file" ];then
                chantitle=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                chanid=$(grep -m 1 "<yt:channelId>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
				thischanneldata=$(extract_feed_entries "${file}" "${MAX_GROUPED_VIDS}" | convert_feed_dates_to_epoch)
                thischannelage=$(most_recent_age "$thischanneldata")
                thischanneltitle=$(printf "§ 📺 %s - %s" "$chantitle" "$thischannelage")
                if [[ "${thischannelage}" =~ ^[0-9]+$ ]] && [ "${thischannelage}" -le "${MAX_CHANNEL_AGE}" ];then
                    printf "\n%s\n%s\n" "$thischanneltitle" "$thischanneldata" >> "${TEMPFILE}"
                fi
            else
                echo "Error in reading subscriptions list!"
            fi
            progress_index=$(( progress_index + 1 ))
            if [ "${show_progress}" == "1" ];then
                log_parse_progress "Grouped data" "${progress_index}" "${total_files}" "${chantitle:-$(basename "$file")}"
            fi
        done
        allfiledata=$(cat ${TEMPFILE})
        loud "[info] Sorting grouped data"
        mark_if_watched "${allfiledata}"
        rm "${TEMPFILE}"
    else
        # This is chronological, all subscriptions
        TEMPFILE=$(mktemp)
        for file in "${feed_files[@]}"; do
            if [ -f "$file" ];then
                parsed_file=$(build_time_channel_cache "${file}")
                if [ -f "${parsed_file}" ];then
                    cat "${parsed_file}" >> "${TEMPFILE}"
                    printf "\n" >> "${TEMPFILE}"
                fi
            else
                echo "Error in reading chronological list!"
            fi
            if [ "${show_progress}" == "1" ];then
                progress_index=$(( progress_index + 1 ))
                chantitle=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
                log_parse_progress "Chronological data" "${progress_index}" "${total_files}" "${chantitle:-$(basename "$file")}"
            fi
        done

        loud "[info] Sorting chronological data"
        mark_if_watched "$(sort -t '|' -k 2,2nr "${TEMPFILE}")"
        rm "${TEMPFILE}"
    fi
}


choose_subscription () {
    TEMPFILE=$(mktemp)
    allchanneldata=""
    watchcount=0
    for file in "$CACHEDIR"/*; do
        [[ "$(basename "$file")" == "watched_files.txt" ]] && continue
        [[ "$(basename "$file")" == "grouped_data.txt" ]] && continue
        [[ "$(basename "$file")" == "time_data.txt" ]] && continue
        if [ $watchcount -gt $watchtop ];then
            wait
            watchcount=0
        fi
        watchcount=$(( watchcount + 1 ))
        (
        id=$(basename ${file})
        updated=$(grep -m 2 "<updated>" "$file" | tail -1 | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' )
        human_date=$(date -d "$updated" +"%d %B")
        title=$(grep -m 1 "<title>" "$file" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | sed 's/|//g'| sed 'N;N;s/\n/|/g' | sed 's/&quot;/‘/g' | sed 's/&amp;/and/g' )
        if [ -n "$id" ];then
            printf "%s (%s)\t\t\t\t|%s|%s\n" "$title" "$human_date" "$id" "$updated" >> "${TEMPFILE}"
        fi
        ) &
    done
    # the awk omits those who don't have an updated date (and are therefore ill-formed)
    rezult=$(printf "1-By last updated\n2-By name A-Z\n3-By name Z-a\n" | fzf_select "Sort how?")
    case $rezult in
        1-*) allchanneldata=$({ echo "§ Exit"; cat "${TEMPFILE}" | awk -F'|' 'NF && $3 != ""' | sort -r -t '|' -k 3; });;
        2-*) allchanneldata=$({ echo "§ Exit"; cat "${TEMPFILE}" | awk -F'|' 'NF && $3 != ""' | sort -t '|' -k 1; });;
        3-*) allchanneldata=$({ echo "§ Exit"; cat "${TEMPFILE}" | awk -F'|' 'NF && $3 != ""' | sort -r -t '|' -k 1; });;
    esac
    rm "${TEMPFILE}"
    channelloop=yes

    while [ "$channelloop" == "yes" ];do
        ChosenChannel=$(echo "$allchanneldata" | fzf_select "Which Channel?" | awk -F '|' '{ print $2 }')
        if [ -f "$CACHEDIR"/"$ChosenChannel" ];then
            loop=yes
            while [ "$loop" == "yes" ];do
                ChosenString=$(mark_if_watched "$(extract_feed_entries "$CACHEDIR"/"$ChosenChannel" 25 | convert_feed_dates_to_epoch)" | fzf_video_select "Which VIDEO?")
                if [ -n "$ChosenString" ];then
                    if [[ "$ChosenString" == "#"* ]] || [[ "$ChosenString" == §* ]] || [[ "$ChosenString" == "" ]] ;then
                        #Exit condition
                        loop=""
                    else
                        VideoId=$(echo "$ChosenString" | awk -F '|' '{print $4}'| sed -e 's/^[ \t]*//')
                        VideoTitle=$(echo "$ChosenString" | awk -F '|' '{print $1}')
                        play_video "${VideoId}" "${VideoTitle}"
                    fi
                else
                    #Exit condition
                    loop=""
                fi
            done
        else
            channelloop=""
        fi
    done
}

choose_video () {
    loop="yes"
    while [ "$loop" == "yes" ]; do
        ChosenString=""
        if [ "$1" == "g" ];then
            if is_file_newer_than_any_xml "${CACHEDIR}" "${CACHEDIR}/grouped_data.txt" && cache_uses_epoch "${CACHEDIR}/grouped_data.txt"; then
                loud "[info] Loading time data file, one moment..."
            else
                loud "[info] Rebuilding grouped data file, one moment..."
                parse_subscriptions g 2>/dev/null > "${CACHEDIR}/grouped_data.txt"
            fi
            feeddata=$(<"${CACHEDIR}/grouped_data.txt")
        else
            if [ -f "${CACHEDIR}/time_data.txt" ] && cache_uses_epoch "${CACHEDIR}/time_data.txt"; then
                loud "[info] Loading time data file, one moment..."
            else
                loud "[info] Rebuilding time data file, one moment..."
                rebuild_time_cache_sync
            fi
            feeddata=$(<"${CACHEDIR}/time_data.txt")
        fi
        # I guess it could just read from a file here, but... ah well.
        ChosenString=$(echo "$feeddata" | fzf_video_select "Which video?")
        if [ "${ChosenString}" == "Error in reading subscriptions list!" ];then
            exit 98
        fi
        if [ "${ChosenString}" == "Error in reading chronological list!" ];then
            exit 97
        fi
        if [[ $ChosenString =~ ^§ ]] || [[ "$ChosenString" == "" ]];then
            loop="no"
        else
            if [ -n "$ChosenString" ];then
                VideoId=$(echo "$ChosenString" | awk -F '|' '{print $4}'| sed -e 's/^[ \t]*//')
                VideoTitle=$(echo "$ChosenString" | awk -F '|' '{print $1}')
                echo "${VideoId}"
                play_video "${VideoId}" "${VideoTitle}"
            else
                loop="no"
            fi
        fi
        if [ "$loop" != "yes" ];then
            break
        fi
    done
}

to_clipboards (){
    input="${1}"
    if [ -f $(which xclip) ];then
        echo "${input}" | xclip -i -selection primary -r
        echo "${input}" | xclip -i -selection secondary -r
        echo "${input}" | xclip -i -selection clipboard -r
    fi
    if [ -f $(which copyq) ];then
        echo "${input}" | tr -d '/n' | /usr/bin/copyq write 0  -
        /usr/bin/copyq select 0
    fi
}


mark_if_not_seen() {
  local search="${1}"
  local file="${2}"
  local tmpfile="$(mktemp)"

  awk -F'|' -v OFS='|' -v search="$search" '
  {
    gsub(/^[ \t]+|[ \t]+$/, "", $4);  # Trim whitespace from 4th field
    if ($4 == search) {
      if ($1 ~ /👀/) {
        print  # Already marked
      } else {
        # Add 👀 after the last matching ANSI bar character
        sub(/([▇█▆▅▄▃▂▁])/, "& 👀", $1)
        print
      }
    } else {
      print
    }
  }' "$file" > "$tmpfile" && mv "$tmpfile" "$file"
}


extract_youtube_id() {
  local url="$1"
  local id

  # Try to extract from full URL (watch?v=...)
  if [[ "$url" =~ (v=|\/)([a-zA-Z0-9_-]{11})([&?]|$) ]]; then
    id="${BASH_REMATCH[2]}"
    echo "$id"
    return 0
  fi

  echo "Invalid or unsupported URL format" >&2
  return 1
}

get_webpage_title() {
  local url="$1"

  curl -Ls "$url" 2>/dev/null | \
    grep -i -o '<title[^>]*>.*</title>' | \
    sed -e 's/<title[^>]*>//I' -e 's:</title>::I' | \
    head -n 1
}

play_video () {
    # see if URL is directly passed through
    if [[ $1 == http*  ]];then
        video_url="${1}"
        TheVideo=$(extract_youtube_id "${video_url}")
        TheTitle=$(get_webpage_title "${video_url}")
    else
        TheVideo="${1}"
        export TheTitle=""
        export TheTitle=$(echo "${2}" | cut -c 4- | sed 's/👀//g' )
        video_url="https://www.youtube.com/watch?v=${TheVideo}"
    fi
    # copy url to clipboards
    to_clipboards "${video_url}"
    loud "Loading video ${TheTitle}..."
	if [ "$YTPOT_BASEURL" != "" ];then
		YTPOT_BASEURL_STRING="--extractor-args $YTPOT_BASEURL "
	fi

    # Run yt-dlp and mpv in a monitored pipeline
    { "${ytube_bin}" "$video_url" \
        -o - \
		--remote-components ejs:github \
		--impersonate chrome \
		--ignore-errors \
        --cookies-from-browser "${YTDLP_COOKIES}" $YTPOT_BASEURL_STRING \
        --extractor-args "youtube:player-client=tv_embedded,mweb,tv,default,-web_safari" \
        --no-check-certificate \
        --no-playlist \
        --mark-watched \
        --continue \
        | "${mpv_bin}" --title=\""${TheTitle}"\" --geometry=${GEOMETRY1} --autofit=${GEOMETRY2} - --force-seekable=yes;
    } || {
        echo "Pipeline exited or mpv was terminated"
        pkill -P $$ "${ytube_bin##*/}" 2>/dev/null
    }

    command=$(printf "%s -c -- \"%s\" \"%s\"" "${grep_bin}" "${TheVideo}" "${CACHEDIR}/watched_files.txt")
    count=$(eval "${command}")
    if [ "$count" == "0" ];then
        loud "[info] Marking watched"
        echo "youtube ${TheVideo}" >> "${CACHEDIR}"/watched_files.txt
        mark_if_not_seen "${TheVideo}" "${CACHEDIR}/grouped_data.txt"
        mark_if_not_seen "${TheVideo}" "${CACHEDIR}/time_data.txt"
    else
        loud "[info] Already watched"
    fi
}

##############################################################################
# Main loop
##############################################################################

preprocess_args "$@"
set -- "${PREPROCESSED_ARGS[@]}"

if [ $# -eq 0 ];then
    interactive_menu
    set -- "${MENU_ARGS[@]}"
fi

while [ $# -gt 0 ]; do
##############################################################################
# Get command-line parameters
##############################################################################

# You have to have the shift or else it will keep looping...
    option="$1"
    case $option in
        https*) play_video "${1}"
                shift
                exit
                ;;
        --preview-item)
                    shift
                    preview_video_entry "$*"
                    exit
                    ;;
        --cli)     export CLIMODE=1
                    shift
                    ;;
        --loud|-l)     export LOUD=1
                    shift
                    ;;
        --refresh|-r)  refresh_subscriptions
                    shift
                    ;;
        --help|-h)     display_help
                    exit
                    ;;
        --import|-i)   shift
                    if [ -f "${1}" ];then
                        InputFile="${1}"
                        import_subscriptions "${InputFile}"
                    else
                        loud "Import must have a csv inputfile following."
                        exit 96
                    fi
                    shift
                    ;;
        --addsub=*)
                    add_subscription_from_url "${1#--addsub=}"
                    shift
                    ;;
        --addsub)   shift
                    add_subscription_from_url "${1}"
                    [ $# -gt 0 ] && shift
                    ;;
        --grouped|-g)
            choose_video g
            exit
            ;;
        --time|--chronological|-t|-c)
            choose_video c
            exit
            ;;
        --subscription|-s)
            choose_subscription
            exit
            ;;
        *)  display_help
            exit
            ;;
    esac
done
