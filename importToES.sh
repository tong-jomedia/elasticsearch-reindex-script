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
importMedia "Movie" "movie" "$ES_MOVIE_INDEX" "id"
importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX" "seq_id"
importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX" "seq_id"

checkReindexFinshed "$ES_GAME_INDEX"
checkReindexFinshed "$ES_BOOK_INDEX"
checkReindexFinshed "$ES_MOVIE_INDEX"
checkReindexFinshed "$ES_MUSIC_ALBUM_INDEX"
checkReindexFinshed "$ES_MUSIC_SONG_INDEX"

compareIndexCountSwitchAlias "$ES_SOFTWARE_INDEX"
compareIndexCountSwitchAlias "$ES_GAME_INDEX"
compareIndexCountSwitchAlias "$ES_BOOK_INDEX"
compareIndexCountSwitchAlias "$ES_MOVIE_INDEX"
compareIndexCountSwitchAlias "$ES_MUSIC_ALBUM_INDEX"
compareIndexCountSwitchAlias "$ES_MUSIC_SONG_INDEX"


allSaveIndexes="${ENV_PREFIX}index_${ES_BOOK_INDEX}_v${nextIndexVersion},\
${ENV_PREFIX}index_${ES_SOFTWARE_INDEX}_v${nextIndexVersion},\
${ENV_PREFIX}index_${ES_GAME_INDEX}_v${nextIndexVersion},\
${ENV_PREFIX}index_${ES_MOVIE_INDEX}_v${nextIndexVersion},\
${ENV_PREFIX}index_${ES_MUSIC_ALBUM_INDEX}_v${nextIndexVersion},\
${ENV_PREFIX}index_${ES_MUSIC_SONG_INDEX}_v${nextIndexVersion}"
saveToS3Snapshot "$allSaveIndexes"
checkSnapshotBackupFinshed
touchDoneFileToS3
