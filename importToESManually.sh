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
            importMedia "Book" "book" "$ES_BOOK_INDEX"; 
            checkReindexFinshed "$ES_BOOK_INDEX" "media"
            compareIndexCountSwitchAlias "$ES_BOOK_INDEX"
            allSaveIndexes="${ENV_PREFIX}index_${ES_BOOK_INDEX}_v${nextIndexVersion}"
            saveToS3Snapshot "$allSaveIndexes"
            checkSnapshotBackupFinshed
            touchDoneFileToS3
            break;;
        [mM]a* ) 
            echo "Reindex Music Album"; 
            importMedia "MusicAlbum" "music_album" "$ES_MUSIC_ALBUM_INDEX" "seq_id"
            checkReindexFinshed "$ES_MUSIC_ALBUM_INDEX" "media"
            allSaveIndexes="${ENV_PREFIX}index_${ES_MUSIC_ALBUM_INDEX}_v${nextIndexVersion}"
            saveToS3Snapshot "$allSaveIndexes"
            checkSnapshotBackupFinshed
            touchDoneFileToS3
            break;;
        [mM]s* ) 
            echo "Reindex Music Song"; 
            importMedia "MusicSong" "music" "$ES_MUSIC_SONG_INDEX";
            compareIndexCountSwitchAlias "$ES_MUSIC_SONG_INDEX"
            compareIndexCountSwitchAlias "$ES_MUSIC_ALBUM_INDEX"
            allSaveIndexes="${ENV_PREFIX}index_${ES_MUSIC_ALBUM_INDEX}_v${nextIndexVersion}"
            saveToS3Snapshot "$allSaveIndexes"
            checkSnapshotBackupFinshed
            touchDoneFileToS3
            break;;
        [mM]o* ) 
            echo "Reindex Movie"; 
            importMedia "Movie" "movie" "$ES_MOVIE_INDEX";
            compareIndexCountSwitchAlias "$ES_MOVIE_INDEX"
            allSaveIndexes="${ENV_PREFIX}index_${ES_MOVIE_INDEX}_v${nextIndexVersion}"
            saveToS3Snapshot "$allSaveIndexes"
            checkSnapshotBackupFinshed
            touchDoneFileToS3
            break;;
        [gG]* ) 
            echo "Reindex Game"; 
            importMedia "Game" "game" "$ES_GAME_INDEX";
            compareIndexCountSwitchAlias "$ES_GAME_INDEX"
            allSaveIndexes="${ENV_PREFIX}index_${ES_GAME_INDEX}_v${nextIndexVersion}"
            saveToS3Snapshot "$allSaveIndexes"
            checkSnapshotBackupFinshed
            touchDoneFileToS3
            break;;
        [sS]* ) 
            echo "Reindex Software"; 
            importMedia "Software" "software" "$ES_SOFTWARE_INDEX";
            compareIndexCountSwitchAlias "$ES_SOFTWARE_INDEX"
            allSaveIndexes="${ENV_PREFIX}index_${ES_SOFTWARE_INDEX}_v${nextIndexVersion}"
            saveToS3Snapshot "$allSaveIndexes"
            checkSnapshotBackupFinshed
            touchDoneFileToS3
            break;;
        [aA]b* ) 
            echo "Reindex Audio Book"; 
            importMedia "AudioBook" "audio_book" "$ES_AUDIO_BOOK_INDEX" "seq_id" "" 100
            compareIndexCountSwitchAlias "$ES_AUDIO_BOOK_INDEX"
            allSaveIndexes="${ENV_PREFIX}index_${ES_AUDIO_BOOK_INDEX}_v${nextIndexVersion}"
            saveToS3Snapshot "$allSaveIndexes"
            checkSnapshotBackupFinshed
            touchDoneFileToS3
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
