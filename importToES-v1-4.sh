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

#importMedia "AudioBook" "audio_book" "$ES_AUDIO_BOOK_INDEX"
#compareIndexCountSwitchAlias "$ES_AUDIO_BOOK_INDEX"

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
