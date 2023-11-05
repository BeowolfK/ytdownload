#!/usr/bin/env bash

set -euo pipefail

if [ -z "$1" ]; then
    echo "Usage: $0 <URL de la vidéo YouTube>"
    exit 1
fi

format=$(yt-dlp -e -F "$1" )

title=$(printf "%s" "$format" | tail -n 1)
header=$(printf "%s" "$format" | head -n 2)

audio=$(printf "%s" "$format" | grep "audio only")
video=$(printf "%s" "$format" | grep "video only")

tmpdir=$(mktemp -d)

printf "%s\n%s\n" "$header" "$audio"
read -p "Quel CODEC audio ? (ID) " codec

printf "%s\n%s\n" "$header" "$video"
read -p "Quel resolution video ? (ID) " res

yt-dlp -f "$res" -o "$tmpdir/video.%(ext)s" "$1" 1> /dev/null
yt-dlp -f "$codec" -o "$tmpdir/audio.%(ext)s" "$1" 1> /dev/null

ffmpeg -y -i $tmpdir/video.* -i $tmpdir/audio.* "$title.mp4"
rm -rf $tmpdir
