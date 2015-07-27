#!/bin/bash
env=$1
baseDir=`dirname "${BASH_SOURCE[0]}"`
sharedDir="${baseDir}/../../shared"

if [ ! -z "$env" ] 
    source "${sharedDir}/config/${env}/config.sh"
else
    source "${sharedDir}/config/config.sh"

tmpDataDir="${sharedDir}/tmpData"

ES_BOOK_INDEX="book"
ES_MUSIC_ALBUM_INDEX="music_album"
ES_MUSIC_SONG_INDEX="music_song"
ES_MOVIE_INDEX="movie"
ES_GAME_INDEX="game"
ES_SOFTWARE_INDEX="software"
ES_AUDIO_BOOK_INDEX="audio_book" 

BOOK_SCORES="book_scores"
GAME_SCORES="game_scores"
MOVIE_SCORES="movie_scores"
MUSIC_SCORES="music_scores"
SOFTWARE_SCORES="software_scores"
AUDIO_BOOK_SCORES="audio_book_scores"
ES_PEOPLE_INDEX="people"

DEFAULT_DEVICE_ID=1

BOOK_MEDIA_TYPE_ID=1
GAME_MEDIA_TYPE_ID=2
MOVIE_MEDIA_TYPE_ID=3
MUSIC_MEDIA_TYPE_ID=4
SOFTWARE_MEDIA_TYPE_ID=5
AUDIO_BOOK_MEDIA_TYPE_ID=7

BOOK_MEDIA_TYPE_NAME="books"
GAME_MEDIA_TYPE_NAME="games"
MOVIE_MEDIA_TYPE_NAME="movies"
MUSIC_MEDIA_TYPE_NAME="albums"
MUSIC_MUSIC_MEDIA_TYPE_NAME="music"
SOFTWARE_MEDIA_TYPE_NAME="software"
AUDIO_BOOK_MEDIA_TYPE_NAME="audio_books"

PC_DEVICE_TYPE_ID=1
MOBILE_DEVICE_TYPE_ID=2
TABLET_DEVICE_TYPE_ID=3
MAC_DEVICE_TYPE_ID=4
CONSOLE_DEVICE_TYPE_ID=5

PC_DEVICE_TYPE_NAME="pc"
MOBILE_DEVICE_TYPE_NAME="mobile"
TABLET_DEVICE_TYPE_NAME="tablet"
MAC_DEVICE_TYPE_NAME="mac"
CONSOLE_DEVICE_TYPE_NAME="console"

MEDIA_GEO_RESTRICT_TABLE_NAME="media_geo_restrict"
BACKUP_REPO="capi_backup"
SNAPSHOT_PREFIX="snapshot_capi_index"
