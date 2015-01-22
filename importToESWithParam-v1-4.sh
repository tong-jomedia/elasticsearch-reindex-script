#!/bin/bash

source "./common.sh"

reindexMedia=$1

while true; do
    case $reindexMedia in
        [b]ooks* ) 
            echo "Reindex Book"; 
            deleteCurrentIndex "$ES_BOOK_INDEX";
            importMedia "Book" "book" "$ES_BOOK_INDEX"; 
            break;;
        [a]lbums* ) 
            echo "Reindex Music Album"; 
            deleteCurrentIndex "$ES_MUSIC_ALBUM_INDEX";
            importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX";
            break;;
        [m]usic* ) 
            echo "Reindex Music Song"; 
            deleteCurrentIndex "$ES_MUSIC_SONG_INDEX";
            importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX";
            break;;
        [m]ovies* ) 
            echo "Reindex Movie"; 
            deleteCurrentIndex "$ES_MOVIE_INDEX";
            importMedia "MusicSong" "music" "$ES_MOVIE_INDEX";
            break;;
        [g]ames* ) 
            echo "Reindex Game"; 
            deleteCurrentIndex "$ES_GAME_INDEX";
            importMedia "Game" "game" "$ES_GAME_INDEX";
            break;;
        [s]oftware* ) 
            echo "Reindex Software"; 
            deleteCurrentIndex "$ES_SOFTWARE_INDEX";
            importMedia "Software" "software" "$ES_SOFTWARE_INDEX";
            break;;
        [a]ll ) 
            echo "Reindex All"; 
            deleteAllCurrentIndex
            importMedia "Book" "book" "$ES_BOOK_INDEX"
            importMedia "Movie" "movie" "$ES_MOVIE_INDEX"
            importMedia "Game" "game" "$ES_GAME_INDEX"
            importMedia "Software" "software" "$ES_SOFTWARE_INDEX"
            importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX"
            importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX";
            break;;
        * ) 
            echo "Reindex All"; 
            deleteAllCurrentIndex
            importMedia "Book" "book" "$ES_BOOK_INDEX"
            importMedia "Movie" "movie" "$ES_MOVIE_INDEX"
            importMedia "Game" "game" "$ES_GAME_INDEX"
            importMedia "Software" "software" "$ES_SOFTWARE_INDEX"
            importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX"
            importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX";
            break;;
    esac

done
