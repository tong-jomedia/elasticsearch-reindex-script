#!/bin/bash
source "common.sh"
deleteAllIndex
#deleteCurrentIndex
#deleteAllIndex
deleteAllCurrentIndex
importMedia "Book" "book" "$ES_BOOK_INDEX"
importMedia "Movie" "movie" "$ES_MOVIE_INDEX"
importMedia "Game" "game" "$ES_GAME_INDEX"
importMedia "Software" "software" "$ES_SOFTWARE_INDEX"
importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX"
importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX"
