#!/bin/bash

source "./common.sh"

currentIndexVersion=$(getIndexVersion)
updateIndexVersion "$currentIndexVersion"
nextIndexVersion=$(getIndexVersion)

while true; do
    read -p "Which to reindexing (b-book | ma-musicAlbum | ms-musicSong | mo-movie | g-game | s-software| all)" reindexMedia
    case $reindexMedia in
        [bB]* ) 
            echo "Reindex Book"; 
            importMedia "Book" "book" "$ES_BOOK_INDEX"; 
            compareIndexCountSwitchAlias "$ES_BOOK_INDEX"
            break;;
        [mM]a* ) 
            echo "Reindex Music Album"; 
            importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX";
            compareIndexCountSwitchAlias "$ES_MUSIC_ALBUM_INDEX"
            break;;
        [mM]s* ) 
            echo "Reindex Music Song"; 
            importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX";
            compareIndexCountSwitchAlias "$ES_MUSIC_SONG_INDEX"
            break;;
        [mM]o* ) 
            echo "Reindex Movie"; 
            deleteCurrentIndex "$ES_MOVIE_INDEX";
            importMedia "Movie" "movie" "$ES_MOVIE_INDEX";
            break;;
        [gG]* ) 
            echo "Reindex Game"; 
            importMedia "Game" "game" "$ES_GAME_INDEX";
            compareIndexCountSwitchAlias "$ES_GAME_INDEX"
            break;;
        [sS]* ) 
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
        * ) echo 'Please answer!'
    esac
done
