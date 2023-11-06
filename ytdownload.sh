#!/usr/bin/env bash

set -euo pipefail

download() {
    tmpdir=$(mktemp -d)
    yt-dlp -f "$res" -o "$tmpdir/video.%(ext)s" "$url" 1> /dev/null
    yt-dlp -f "$codec" -o "$tmpdir/audio.%(ext)s" "$url" 1> /dev/null
    ffmpeg -y -i $tmpdir/video.* -i $tmpdir/audio.* "$title.mp4" &> /dev/null
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
        codec=$(dialog --title "Choix du flux audio" --clear --menu "$header" 0 0 0 "${audio_dialog[@]}" 2>&1 >/dev/tty)

        video_dialog=()
        while IFS= read -r line; do
            id=$(printf "%s" "$line" | grep -o '^[0-9]\+')
            # echo "ID : $id"
            other=$(printf "%s" "$line" | grep -o ' .*')
            # echo "Ligne : $other"
            video_dialog+=("$id" "$other") 
        done <<< "$video"
        res=$(dialog --title "Choix du flux video" --clear --menu "$header" 0 0 0 "${video_dialog[@]}" 2>&1 >/dev/tty)
        tmpdir=$(mktemp -d)
        {
            printf "%d\n" 0
            yt-dlp -f "$res" -o "$tmpdir/video.%(ext)s" "$url" 1> /dev/null
            printf "%d\n" 25
            yt-dlp -f "$codec" -o "$tmpdir/audio.%(ext)s" "$url" 1> /dev/null
            printf "%d\n" 50
            ffmpeg -y -i $tmpdir/video.* -i $tmpdir/audio.* "$title.mp4" &> /dev/null
            printf "%d\n" 75
            rm -rf $tmpdir
            printf "%d\n" 100
        } | dialog --title "Téléchargement de la vidéo YouTube" --gauge "Le téléchargement du flux vidéo et audio est en cours.\nLe muxing est effectué une fois ce deux flux téléchargés.\nLes fichiers temporaires seront ensuite supprimés" 0 0 
        clear
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

