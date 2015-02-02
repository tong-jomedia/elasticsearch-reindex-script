#!/bin/bash

source "./common.sh"

reindexMedia=$1
currentIndexVersion=$(getIndexVersion)
updateIndexVersion "$currentIndexVersion"
nextIndexVersion=$((currentIndexVersion + 1))

while true; do
    case $reindexMedia in
        [b]ooks* ) 
            echo "Reindex Book"; 
            importMedia "Book" "book" "$ES_BOOK_INDEX"; 
            compareIndexCountSwitchAlias "$ES_BOOK_INDEX"
            break;;
        [a]lbums* ) 
            echo "Reindex Music Album"; 
            importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX";
            compareIndexCountSwitchAlias "$ES_MUSIC_ALBUM_INDEX"
            break;;
        [m]usic* ) 
            echo "Reindex Music Song"; 
            importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX";
            compareIndexCountSwitchAlias "$ES_MUSIC_SONG_INDEX"
            break;;
        [m]ovies* ) 
            echo "Reindex Movie"; 
            importMedia "Movie" "movie" "$ES_MOVIE_INDEX";
            compareIndexCountSwitchAlias "$ES_MOVIE_INDEX"
            break;;
        [g]ames* ) 
            echo "Reindex Game"; 
            importMedia "Game" "game" "$ES_GAME_INDEX";
            compareIndexCountSwitchAlias "$ES_GAME_INDEX"
            break;;
        [s]oftware* ) 
            echo "Reindex Software"; 
            importMedia "Software" "software" "$ES_SOFTWARE_INDEX";
            compareIndexCountSwitchAlias "$ES_SOFTWARE_INDEX"
            break;;
        [a]ll ) 
            echo "Reindex All"; 
            importMedia "Software" "software" "$ES_SOFTWARE_INDEX"
            importMedia "Game" "game" "$ES_GAME_INDEX"
            importMedia "Book" "book" "$ES_BOOK_INDEX"
            importMedia "Movie" "movie" "$ES_MOVIE_INDEX"
            importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX"
            importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX"

            compareIndexCountSwitchAlias "$ES_SOFTWARE_INDEX"
            compareIndexCountSwitchAlias "$ES_GAME_INDEX"
            compareIndexCountSwitchAlias "$ES_BOOK_INDEX"
            compareIndexCountSwitchAlias "$ES_MOVIE_INDEX"
            compareIndexCountSwitchAlias "$ES_MUSIC_ALBUM_INDEX"
            compareIndexCountSwitchAlias "$ES_MUSIC_SONG_INDEX"
            break;;
        * ) 
            echo "Reindex All"; 
            importMedia "Software" "software" "$ES_SOFTWARE_INDEX"
            importMedia "Game" "game" "$ES_GAME_INDEX"
            importMedia "Book" "book" "$ES_BOOK_INDEX"
            importMedia "Movie" "movie" "$ES_MOVIE_INDEX"
            importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX"
            importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX"

            compareIndexCountSwitchAlias "$ES_SOFTWARE_INDEX"
            compareIndexCountSwitchAlias "$ES_GAME_INDEX"
            compareIndexCountSwitchAlias "$ES_BOOK_INDEX"
            compareIndexCountSwitchAlias "$ES_MOVIE_INDEX"
            compareIndexCountSwitchAlias "$ES_MUSIC_ALBUM_INDEX"
            compareIndexCountSwitchAlias "$ES_MUSIC_SONG_INDEX"
            break;;
    esac

done
