#!/usr/bin/env bash
#
# YTDownload
#
# Release: 1.0 of 2023/06/11
# 2023, Kénan Meylan
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU  General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

set -euo pipefail

verify() {
    if ! echo "$1" | grep -q -E '^(https?://)?(www\.)?(youtube|youtu|youtube-nocookie)\.(com|be)/.*$';
    then
        printf "%s\n" "L'URL ne provient pas de YouTube."
        return -1
    fi
}

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
        url="$(dialog --title "URL de la vidéo YouTube" --inputbox "URL de la vidéo YouTube a télécharger : " 0 0 2>&1 >/dev/tty)"
        verify $url
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
        url="$(zenity --entry --height=500 --width=800 --text="URL de la vidéo YouTube à télécharger")"
        verify $url
        extract_data $url

        audio_zenity=()
        while IFS= read -r line; do
            id=$(printf "%s" "$line" | grep -o '^[0-9]\+')
            # echo "ID : $id"
            other=$(printf "%s" "$line" | grep -o ' .*')
            # echo "Ligne : $other"
            audio_zenity+=("$id" "$other") 
        done <<< "$audio"
        codec=$(zenity --list --height=500 --width=800 --title="Choisissez les bogues à afficher" --column="ID CODEC" --column="Description" "${audio_zenity[@]}")
        
        video_zenity=()
        while IFS= read -r line; do
            id=$(printf "%s" "$line" | grep -o '^[0-9]\+')
            # echo "ID : $id"
            other=$(printf "%s" "$line" | grep -o ' .*')
            # echo "Ligne : $other"
            video_zenity+=("$id" "$other") 
        done <<< "$video"
        res=$(zenity --list --height=500 --width=800 --title="Choisissez les bogues à afficher" --column="ID CODEC" --column="Description" "${video_zenity[@]}")
        if [ -z $res ] | [ -z $codec ]
        then
            printf "Aucun codec audio ou vidéo sélectionné\n"
            exit -1
        fi
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
        } | zenity --progress  --height=500 --width=800 --title "Téléchargement de la vidéo YouTube" --text "Le téléchargement du flux vidéo et audio est en cours.\nLe muxing est effectué une fois ce deux flux téléchargés.\nLes fichiers temporaires seront ensuite supprimés" --percentage=0
        ;;

    *)
        url=$1
        verify $url
        extract_data $url

        printf "%s\n%s\n" "$header" "$audio"
        read -p "Quel CODEC audio ? (ID) " codec
        printf "%s\n%s\n" "$header" "$video"
        read -p "Quel resolution video ? (ID) " res

        download
        ;;
esac

