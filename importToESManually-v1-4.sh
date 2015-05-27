#!/bin/bash

baseDir=`dirname "${BASH_SOURCE[0]}"`
source "${baseDir}/common.sh"
currentIndexVersion=$(getIndexVersion)
updateIndexVersion "$currentIndexVersion"
nextIndexVersion=$((currentIndexVersion + 1))

while true; do
    read -p "Which to reindexing (b-book | ma-musicAlbum | ms-musicSong | mo-movie | g-game | s-software| all)" reindexMedia
    case $reindexMedia in
        [bB]* ) 
            echo "Reindex Book"; 
            importMedia "Book" "book" "$ES_BOOK_INDEX" "seq_id"; 
            compareIndexCountSwitchAlias "$ES_BOOK_INDEX"
            break;;
        [mM]a* ) 
            echo "Reindex Music Album"; 
            importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX" "seq_id";
            compareIndexCountSwitchAlias "$ES_MUSIC_ALBUM_INDEX"
            break;;
        [mM]s* ) 
            echo "Reindex Music Song"; 
            importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX" "seq_id";
            compareIndexCountSwitchAlias "$ES_MUSIC_SONG_INDEX"
            break;;
        [mM]o* ) 
            echo "Reindex Movie"; 
            importMedia "Movie" "movie" "$ES_MOVIE_INDEX" "id";
            compareIndexCountSwitchAlias "$ES_MOVIE_INDEX"
            break;;
        [gG]* ) 
            echo "Reindex Game"; 
            importMedia "Game" "game" "$ES_GAME_INDEX" "id";
            compareIndexCountSwitchAlias "$ES_GAME_INDEX"
            break;;
        [sS]* ) 
            echo "Reindex Software"; 
            importMedia "Software" "software" "$ES_SOFTWARE_INDEX" "id";
            compareIndexCountSwitchAlias "$ES_SOFTWARE_INDEX"
            break;;
        [pP]* ) 
            echo "Reindex People"; 
            importMedia "MusicAlbumArtist" "music_album_artists" "$ES_PEOPLE_INDEX" "seq_id" "music_album_artist"
            importMedia "MusicSongArtist" "music_song_artists" "$ES_PEOPLE_INDEX" "seq_id" "music_song_artist"
            importMedia "BookAuthor" "author" "$ES_PEOPLE_INDEX" "id" "book_author"
            importMedia "BookArtist" "artists" "$ES_PEOPLE_INDEX" "id" "book_artist"
            importMedia "MovieActor" "actors" "$ES_PEOPLE_INDEX" "id" "movie_actor"
            importMedia "MovieWriter" "writers" "$ES_PEOPLE_INDEX" "id" "movie_writer"
            importMedia "MovieProducer" "producers" "$ES_PEOPLE_INDEX" "id" "movie_producer"
            importMedia "MovieDirector" "directors" "$ES_PEOPLE_INDEX" "id" "movie_director"
            importMedia "GameDeveloper" "developer" "$ES_PEOPLE_INDEX" "id" "game_developer"
            compareIndexCountSwitchAlias "$ES_PEOPLE_INDEX"
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
