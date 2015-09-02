#!/bin/bash
baseDir=`dirname "${BASH_SOURCE[0]}"`
source "${baseDir}/common.sh"
currentIndexVersion=$(getIndexVersion)
echo $currentIndexVersion
previousIndexVersion=$((currentIndexVersion - 1))
updateIndexVersion "$currentIndexVersion"

nextIndexVersion=$((currentIndexVersion + 1))
echo $nextIndexVersion
#deleteCurrentIndex
#deleteAllIndex

importMedia "Software" "software" "$ES_SOFTWARE_INDEX" "id"
importMedia "Game" "game" "$ES_GAME_INDEX" "id"
importMedia "Book" "book" "$ES_BOOK_INDEX" "seq_id"
importMedia "AudioBook" "audio_book" "$ES_AUDIO_BOOK_INDEX" "seq_id" "" 100
importMedia "Movie" "movie" "$ES_MOVIE_INDEX" "id"
importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX" "seq_id"
importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX" "seq_id"

importMedia "MusicAlbumArtist" "music_album_artists" "$ES_PEOPLE_INDEX" "seq_id" "music_album_artist"
importMedia "MusicSongArtist" "music_song_artists" "$ES_PEOPLE_INDEX" "seq_id" "music_song_artist"
importMedia "BookAuthor" "author" "$ES_PEOPLE_INDEX" "id" "book_author"
importMedia "BookArtist" "artists" "$ES_PEOPLE_INDEX" "id" "book_artist"
importMedia "MovieActor" "actors" "$ES_PEOPLE_INDEX" "id" "movie_actor"
importMedia "MovieWriter" "writers" "$ES_PEOPLE_INDEX" "id" "movie_writer"
importMedia "MovieProducer" "producers" "$ES_PEOPLE_INDEX" "id" "movie_producer"
importMedia "MovieDirector" "directors" "$ES_PEOPLE_INDEX" "id" "movie_director"
importMedia "GameDeveloper" "developer" "$ES_PEOPLE_INDEX" "id" "game_developer"


compareIndexCountSwitchAlias "$ES_SOFTWARE_INDEX"
compareIndexCountSwitchAlias "$ES_GAME_INDEX"
compareIndexCountSwitchAlias "$ES_BOOK_INDEX"
compareIndexCountSwitchAlias "$ES_MOVIE_INDEX"
compareIndexCountSwitchAlias "$ES_MUSIC_ALBUM_INDEX"
compareIndexCountSwitchAlias "$ES_MUSIC_SONG_INDEX"
compareIndexCountSwitchAlias "$ES_AUDIO_BOOK_INDEX"
compareIndexCountSwitchAlias "$ES_PEOPLE_INDEX"
