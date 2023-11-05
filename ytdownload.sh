#!/usr/bin/env bash

set -euo pipefail

    download() {
    tmpdir=$(mktemp -d)
    yt-dlp -f "$res" -o "$tmpdir/video.%(ext)s" "$url" 1> /dev/null
    yt-dlp -f "$codec" -o "$tmpdir/audio.%(ext)s" "$url" 1> /dev/null
    ffmpeg -y -i $tmpdir/video.* -i $tmpdir/audio.* "$title.mp4" 1> /dev/null
    rm -rf $tmpdir
}

extract_data(){
    format=$(yt-dlp -e -F "$1" )

    title=$(printf "%s" "$format" | tail -n 1)
    header=$(printf "%s" "$format" | head -n 2)

    audio=$(printf "%s" "$format" | grep "audio only")
    video=$(printf "%s" "$format" | grep "video only")
}

case "$1" in
    "-h"|"--help")
        echo "help"
        return 0
        ;;
    "-tui")
        url=$2
        extract_data $url
        audio_dialog=()
        while IFS= read -r line; do
            id=$(printf "%s" "$line" | grep -o '^[0-9]\+')
            # echo "ID : $id"
            other=$(printf "%s" "$line" | grep -o ' .*')
            # echo "Ligne : $other"
            audio_dialog+=("$id" "$other") 
        done <<< "$audio"
        choice1=$(dialog --title "Choix du flux audio" --clear --menu "$header" 40 50 30 "${audio_dialog[@]}" 2>&1 >/dev/tty)
        echo $choice1
        ;;
    "-gui")
        echo "gui"
        ;;
    *)
        url=$1
        if ! echo "$url" | grep -q -E '^(https?://)?(www\.)?(youtube|youtu|youtube-nocookie)\.(com|be)/.*$';
        then
            echo "L'URL ne provient pas de YouTube."
            return -1
        fi

        extract_data $url

        printf "%s\n%s\n" "$header" "$audio"
        read -p "Quel CODEC audio ? (ID) " codec

        printf "%s\n%s\n" "$header" "$video"
        read -p "Quel resolution video ? (ID) " res

        download

        ;;
esac

