#!/bin/bash
source "common.sh"
currentIndexVersion=$(getIndexVersion)
echo $currentIndexVersion

previousIndexVersion=$((currentIndexVersion - 1))
updateIndexVersion "$currentIndexVersion"

nextIndexVersion=$(getIndexVersion)
echo $nextIndexVersion
#deleteCurrentIndex
#deleteAllIndex

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
