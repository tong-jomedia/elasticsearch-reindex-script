#!/bin/bash

source "common.sh"
while true; do
    read -p "Which to reindexing (b-book | ma-musicAlbum | ms-musicSong | mo-movie | g-game | s-software| all)" reindexMedia
    case $reindexMedia in
        [bB]* ) 
            echo "Reindex Book"; 
            deleteCurrentIndex "$ES_BOOK_INDEX";
            importMedia "Book" "book" "$ES_BOOK_INDEX"; 
            break;;
        [mM]a* ) 
            echo "Reindex Music Album"; 
            deleteCurrentIndex "$ES_MUSIC_ALBUM_INDEX";
            importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX";
            break;;
        [mM]s* ) 
            echo "Reindex Music Song"; 
            deleteCurrentIndex "$ES_MUSIC_SONG_INDEX";
            importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX";
            break;;
        [mM]o* ) 
            echo "Reindex Movie"; 
            deleteCurrentIndex "$ES_MOVIE_INDEX";
            importMedia "Movie" "movie" "$ES_MOVIE_INDEX";
            break;;
        [gG]* ) 
            echo "Reindex Game"; 
            deleteCurrentIndex "$ES_GAME_INDEX";
            importMedia "Game" "game" "$ES_GAME_INDEX";
            break;;
        [sS]* ) 
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
        * ) echo 'Please answer!'
    esac
done
