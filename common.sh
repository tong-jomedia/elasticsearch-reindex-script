#!/bin/bash
ES_BOOK_INDEX="book"
ES_MUSIC_ALBUM_INDEX="music_album"
ES_MUSIC_SONG_INDEX="music_song"
ES_MOVIE_INDEX="movie"
ES_GAME_INDEX="game"
ES_SOFTWARE_INDEX="software"
ES_AUDIO_BOOK_INDEX="audio_book" 

BOOK_SCORES="book_scores"
GAME_SCORES="game_scores"
MOVIE_SCORES="movie_scores"
MUSIC_SCORES="music_scores"
SOFTWARE_SCORES="software_scores"
AUDIO_BOOK_SCORES="audio_book_scores"

DEFAULT_DEVICE_ID=1

BOOK_MEDIA_TYPE_ID=1
GAME_MEDIA_TYPE_ID=2
MOVIE_MEDIA_TYPE_ID=3
MUSIC_MEDIA_TYPE_ID=4
SOFTWARE_MEDIA_TYPE_ID=5
AUDIO_BOOK_MEDIA_TYPE_ID=7

BOOK_MEDIA_TYPE_NAME="books"
GAME_MEDIA_TYPE_NAME="games"
MOVIE_MEDIA_TYPE_NAME="movies"
MUSIC_MEDIA_TYPE_NAME="albums"
MUSIC_MUSIC_MEDIA_TYPE_NAME="music"
SOFTWARE_MEDIA_TYPE_NAME="software"
AUDIO_BOOK_MEDIA_TYPE_NAME="audio_books"

PC_DEVICE_TYPE_ID=1
MOBILE_DEVICE_TYPE_ID=2
TABLET_DEVICE_TYPE_ID=3
MAC_DEVICE_TYPE_ID=4
CONSOLE_DEVICE_TYPE_ID=5

PC_DEVICE_TYPE_NAME="pc"
MOBILE_DEVICE_TYPE_NAME="mobile"
TABLET_DEVICE_TYPE_NAME="tablet"
MAC_DEVICE_TYPE_NAME="mac"
CONSOLE_DEVICE_TYPE_NAME="console"

MEDIA_GEO_RESTRICT_TABLE_NAME="media_geo_restrict"

baseDir=`dirname "${BASH_SOURCE[0]}"`
source "${baseDir}/../config.sh"

function getIndexVersionByFile()
{
    local currentIndexVersion=$(cat $baseDir'/../tmpData/indexVersion')
    if [ -z $currentIndexVersion ]; then
        currentIndexVersion=1
    fi
    echo "$currentIndexVersion"
}
function getIndexVersion()
{
    local mediaIndex=$ES_SOFTWARE_INDEX 
    local allIndexes=$(curl -s -XGET $ES_HOST':'$ES_PORT'/_cat/indices/'$ENV_PREFIX'index_*' | grep -Po $ENV_PREFIX'index_(\w+)_v(\d+)')
    allIndexes=$(echo $allIndexes | tr "\n\r" "\n\r")
    local currentIndexVersion=0
    for oneIndex in $allIndexes 
    do
#        local version=${oneIndex/$ENV_PREFIX'index_(\w+)_v'/''}
        local version=$(echo $oneIndex | grep -o '[0-9]*')
        if [ "$version" -ge "$currentIndexVersion" ]
        then
            currentIndexVersion=$version
        fi
    done
    echo "$currentIndexVersion"
}

function updateIndexVersion()
{
    local currentIndexVersion=$1
    local newIndexVersion=$((currentIndexVersion+1))
    if [ "$newIndexVersion" -ge "$MAX_VERSION_NUM_TO_RESET" ]
    then
        newIndexVersion=1
    fi

    echo $newIndexVersion | cat > "${baseDir}/../tmpData/indexVersion"
}

function deleteAllIndex()
{
    curl -XDELETE 'http://'$ES_HOST':'$ES_PORT'/_all'
}

function deleteAllCurrentIndex()
{
    indexes=($ES_BOOK_INDEX $ES_MUSIC_ALBUM_INDEX $ES_MOVIE_INDEX $ES_GAME_INDEX $ES_MUSIC_SONG_INDEX $ES_SOFTWARE_INDEX)
    for indexName in "${indexes[@]}"
    do
        curl -XDELETE $ES_HOST':'$ES_PORT'/_river/'$indexName'_river/'
        curl -XGET $ES_HOST':'$ES_PORT'/_river/_refresh'
        curl -XDELETE $ES_HOST':'$ES_PORT'/'$indexName
    done

}

function deleteCurrentIndex()
{
    #indexes=($ES_BOOK_INDEX $ES_MUSIC_ALBUM_INDEX $ES_MOVIE_INDEX $ES_GAME_INDEX $ES_MUSIC_SONG_INDEX $ES_SOFTWARE_INDEX)
	local indexes=(${ENV_PREFIX}$1_v$currentIndexVersion)
    for indexName in "${indexes[@]}"
    do
        curl -XDELETE $ES_HOST':'$ES_PORT'/_river/'$indexName'_river/'
        curl -XGET $ES_HOST':'$ES_PORT'/_river/_refresh'
        curl -XDELETE $ES_HOST':'$ES_PORT'/'$indexName
    done
}

function deleteIndexByVersion()
{
    local version=($2)
	local indexes=($1_v$version)
    indexes="${ENV_PREFIX}index_"${indexes}
    for indexName in "${indexes[@]}"
    do
        curl -XDELETE $ES_HOST':'$ES_PORT'/_river/'$indexName'_river/'
        curl -XGET $ES_HOST':'$ES_PORT'/_river/_refresh'
        curl -XDELETE $ES_HOST':'$ES_PORT'/'$indexName
    done
}

function deleteAllPreviousIndexesByMedia()
{	
    local mediaIndex=($1)
    local nextVersionIndex="${ENV_PREFIX}index_${mediaIndex}_v${nextIndexVersion}"
    local allPreviousIndexes=$(getAllPreviousIndexesByMedia "$mediaIndex")
    echo $nextVersionIndex
    for onePreviousIndex in $allPreviousIndexes 
    do
        if [ "$onePreviousIndex" != "$nextVersionIndex" ]
        then
            echo $onePreviousIndex
            curl -XDELETE $ES_HOST':'$ES_PORT'/_river/'$onePreviousIndex'_river/'
            curl -XGET $ES_HOST':'$ES_PORT'/_river/_refresh'
            curl -XDELETE $ES_HOST':'$ES_PORT'/'$onePreviousIndex
        fi
    done
}

function getAllPreviousIndexesByMedia()
{
    local mediaIndex=($1)
    local allIndexes=$(curl -s -XGET $ES_HOST':'$ES_PORT'/_cat/indices/'$ENV_PREFIX'index_'$mediaIndex'*' | grep -Po $ENV_PREFIX'index_'$mediaIndex'_v(\d+)')
    allIndexes=$(echo $allIndexes | tr "\n\r" "\n\r")
    echo "$allIndexes"
}

function getCheckQuery()
{
    local offset=$1
    local batchSize=$2
    local tableName=$3
    local query="SELECT max(id) FROM "$tableName" WHERE id >= "${offset}" AND id < "${batchSize}";"
    echo "$query"
}

function getMaxIdCheckQuery()
{
    local tableName=$1
    local keyColumName=$2
    local query="SELECT max("$keyColumName") FROM "$tableName";"
    echo "$query"
}

function getImportBySectionQuery()
{
    local mediaType=$1
    local mediaTableName=$2
    local offset=0
    local batchSize=${LIMIT}

    if [ "$mediaTableName" = "audio_book" ] 
    then
        local getMaxIdCheckQuery=$(getMaxIdCheckQuery "$mediaTableName" "seq_id")
    else 
        local getMaxIdCheckQuery=$(getMaxIdCheckQuery "$mediaTableName" "id")
    fi

    local maxId=$(/usr/bin/mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" -D "$DB_NAME" -e "$getMaxIdCheckQuery" | awk 'NR>1') 

    local allQuery=""
    while [ ${offset} -le ${maxId} ]
    do
        local singleImportQuery=$(getQueryFor${mediaType} $offset $batchSize)

        local tempQuery='{"statement" : "'$singleImportQuery'"},'
        allQuery=$allQuery$tempQuery
        offset=$(($offset+$LIMIT))
        batchSize=$(($offset+$LIMIT))
    done

    local importQuery="${allQuery%?}"
    echo "$importQuery"
}

function getMapping()
{
    local mediaType=$1
    local singleMapping=$(getMappingFor${mediaType})

    echo "$singleMapping"
}

function compareIndexCountSwitchAlias()
{
    local exitChecking=0
    local indexPrefix=$1
    local indexCurrent="${ENV_PREFIX}index_${indexPrefix}_v${currentIndexVersion}"
    local indexNext="${ENV_PREFIX}index_${indexPrefix}_v${nextIndexVersion}"

#    echo $indexCurrent
#    echo $indexNext
#    echo $currentIndexCount
#    echo $nextIndexCount
    local timeOutCounter=0
    while [ $exitChecking -ne 1 ]
    do
        sleep $CHECK_INTERVAL
        timeOutCounter=$((timeOutCounter + CHECK_INTERVAL))
        local currentIndexCount=$(getCountOfIndex "$indexCurrent")
        local nextIndexCount=$(getCountOfIndex "$indexNext")
        if [ -z $currentIndexCount ]; then
            currentIndexCount=0
        fi
        if [ -z $nextIndexCount ]; then
            nextIndexCount=0
        fi

        echo $currentIndexCount
        echo $nextIndexCount
        if [ "$nextIndexCount" -ge "$currentIndexCount" ] 
        then
            switchAliasByIndex "$indexPrefix"
            deleteAllPreviousIndexesByMedia "$indexPrefix"
            exitChecking=1
        fi

        #check time out
        if [ "$timeOutCounter" -ge "$MAX_TIMEOUT_CHECK" ]
        then
            if [ "$nextIndexCount" -ne 0 ] 
            then
                switchAliasByIndex "$indexPrefix"
                deleteAllPreviousIndexesByMedia "$indexPrefix"
            fi
            exitChecking=1
        fi
    done
}

function getCountOfIndex()
{
    local index="$1"
    local count=$(curl -s -XGET $ES_HOST':'$ES_PORT'/'$index'/media/_count' | grep -Po '"count":(\d*?,|.*?[^\\]",)' | grep -o '[0-9]*')
    echo "$count"
}

function switchAliasByIndex()
{
    local indexPrefix=$1
    local alias="${ENV_PREFIX}all_media_${indexPrefix}"
    local indexPrev="${ENV_PREFIX}index_${indexPrefix}*"
    local indexNext="${ENV_PREFIX}index_${indexPrefix}_v${nextIndexVersion}"
    curl -XPOST $ES_HOST':'$ES_PORT'/_aliases' -d '{
        "actions": [
            {"remove": {
                "alias": "'$alias'",
                "index": "'$indexPrev'"
            }},
            {"add": {
                "alias": "'$alias'",
                "index": "'$indexNext'"
            }}
        ]
    }'
}

function importMedia()
{
    local mediaTypeName=$1
    local mediaTableName=$2
    local indexName="${ENV_PREFIX}index_${3}_v${nextIndexVersion}" 

    local query=$(getImportBySectionQuery "$mediaTypeName" "$mediaTableName")
    local mapping=$(getMapping "$mediaTypeName" "$mediaTableName")
    local jsonString='{
        "type" : "jdbc",
        "jdbc" : {
            "url" : "'$JDBC_URL'",
            "user" : "'$DB_USER'",
            "password" : "'$DB_PASS'",
            "index": "'$indexName'",
            "type": "media",
            "autocommit": true,
            "maxbulkactions" : 10000,
            "maxconcurrrentbulkactions": 10,
            "fetchsize" : 100,
            "sql" : ['"$query"'],
            "type_mapping" : {
                "media" : {
                    "properties" : {
                        '"$mapping"' 
                    }
                }
            }

        }
    }'
    echo "${jsonString}" | cat > $baseDir'/../tmpData/'$mediaTypeName
    curl -XPUT $ES_HOST':'$ES_PORT'/_river/'$indexName'_river/_meta' -d @$baseDir'/../tmpData/'$mediaTypeName

}

function getMappingForBook()
{
    local mapping='"people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "author" : {"type": "string", "index": "not_analyzed"},
                            "artist" : {"type": "string", "index": "not_analyzed"}
                        }
                    },
                    "content_segments" : {"type": "string", "index": "not_analyzed"},
                    "genre" : {"type": "string", "index": "not_analyzed"},
                    "languages" : {"type" : "string"},
                    "membership_exclusion" : {
                        "type" : "nested",
                        "include_in_parent": true,
                        "properties" : {
                            "membership_type_id" : {"type": "string"},
                            "site_id" : {"type": "string"}
                        }
                    },
                    "membership_type_site_exclusion_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '
    echo "$mapping"
}
function getMappingForMusicSong()
{
    local mapping='"people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "artist" : {"type": "string", "index": "not_analyzed"}
                        }
                    }'
    echo "$mapping"
}
function getMappingForMusicAlbum()
{
    local mapping='"people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "artist" : {"type": "string", "index": "not_analyzed"}
                        }
                    },
                    "content_segments" : {"type": "string", "index": "not_analyzed"},
                    "genre" : {"type": "string", "index": "not_analyzed"},
                    "languages" : {"type" : "string"},
                    "membership_type_site_exclusion_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '
    echo "$mapping"
}
function getMappingForMovie()
{
    local mapping='"people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "actor" : {"type": "string", "index": "not_analyzed"},
                            "director" : {"type": "string", "index": "not_analyzed"},
                            "producer" : {"type": "string", "index": "not_analyzed"},
                            "writer" : {"type": "string", "index": "not_analyzed"}
                        }
                    },
                    "content_segments" : {"type": "string", "index": "not_analyzed"},
                    "genre" : {"type": "string", "index": "not_analyzed"},
                    "languages" : {"type" : "string"},
                    "membership_type_site_exclusion_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '
    echo "$mapping"
}
function getMappingForGame()
{
    local mapping='"people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "developer" : {"type": "string","index": "not_analyzed"}
                        }
                    },
                    "content_segments" : {"type": "string", "index": "not_analyzed"},
                    "genre" : {"type": "string", "index": "not_analyzed"},
                    "game_type" : {
                        "type" : "string",
                        "store" : "yes",
                        "index":"not_analyzed"
                     },
                    "languages" : {"type" : "string"},
                    "membership_type_site_exclusion_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '

    echo "$mapping"
}
function getMappingForSoftware()
{
    local mapping='"people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "software_type" : {"type": "string","index": "not_analyzed"}
                        }
                    },
                    "content_segments" : {"type": "string", "index": "not_analyzed"},
                    "genre" : {"type": "string", "index": "not_analyzed"},
                    "languages" : {"type" : "string"},
                    "membership_exclusion" : {
                        "type" : "nested",
                        "include_in_parent": true,
                        "properties" : {
                            "membership_type_id" : {"type": "string"},
                            "site_id" : {"type": "string"}
                        }
                    },
                    "membership_type_site_exclusion_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '
    echo "$mapping"
}
function getMappingForAudioBook()
{
    local mapping='"people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "author" : {"type": "string"},
                            "narrator" : {"type": "string"}
                        }
                    },
                    "languages" : {"type" : "string"},
                    "ma_release_date" : {"type" : "date"},
                    "media_id" : {
                        "type" : "string", 
                        "index": "not_analyzed"
                    },
                    "id" : {
                        "type" : "string", 
                        "index": "not_analyzed"
                    },
                    "membership_exclusion" : {
                        "type" : "nested",
                        "include_in_parent": true,
                        "properties" : {
                            "membership_type_id" : {"type": "string"},
                            "site_id" : {"type": "string"}
                        }
                    },
                    "membership_type_site_exclusion_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '
    echo "$mapping"
}

function getQueryForBook()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT  0 AS episode_id, m.*, \
            CAST(CONCAT('${BOOK_MEDIA_TYPE_ID}', '-', m.id) AS CHAR) AS _id, \
            '${BOOK_MEDIA_TYPE_NAME}' AS media_type, m.id AS media_id, \
            l.status AS licensor_status, \
            l.is_public, \
            l.name AS licensor_name, \
            mgr.restrict_type AS 'restrict.type', \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            GROUP_CONCAT(DISTINCT mgr.country_code ORDER BY mgr.date_start) AS 'restrict.country_code[]', \
            CAST(GROUP_CONCAT(mgr.date_start) AS CHAR) AS 'restrict.date[]', \
            GROUP_CONCAT(DISTINCT au.\`name\`) AS 'people.author[]', \
            GROUP_CONCAT(DISTINCT ar.\`name\`) AS 'people.artist[]', \
            GROUP_CONCAT(DISTINCT gb.\`name\`) AS 'genre[]', \
            GROUP_CONCAT(DISTINCT scfe.site_id) AS 'site_exclusion_id[]', \
            GROUP_CONCAT(DISTINCT mal.\`name\`) AS 'languages[]', \
            CAST(GROUP_CONCAT(CONCAT(mtscfe.membership_type_id, '-', mtscfe.site_id)) AS CHAR) \
             AS 'membership_type_site_exclusion_id[]', \
            (SELECT mss.total_score FROM ${BOOK_SCORES} mss WHERE mss.device_type_id = ${PC_DEVICE_TYPE_ID} \
             AND mss.id = m.id) \
             AS 'sorting_score.${PC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${BOOK_SCORES} mss WHERE mss.device_type_id = ${MOBILE_DEVICE_TYPE_ID} \
             AND mss.id = m.id) \
             AS 'sorting_score.${MOBILE_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${BOOK_SCORES} mss WHERE mss.device_type_id = ${TABLET_DEVICE_TYPE_ID} \
             AND mss.id = m.id) \
             AS 'sorting_score.${TABLET_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${BOOK_SCORES} mss WHERE mss.device_type_id = ${MAC_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MAC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${BOOK_SCORES} mss WHERE mss.device_type_id = ${CONSOLE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${CONSOLE_DEVICE_TYPE_NAME}' \
        FROM (SELECT * FROM book WHERE id >= ${offset} AND id < ${batchSize}) AS m \
        LEFT JOIN book_authors AS bau ON bau.book_id = m.id \
        LEFT JOIN author AS au ON au.id = bau.author_id \
        LEFT JOIN book_artists AS bar ON m.id = bar.book_id \
        LEFT JOIN artists AS ar ON ar.id = bar.artist_id \
        LEFT JOIN book_genres AS bg ON bg.book_id = m.id \
        LEFT JOIN genre_book AS gb ON gb.id = bg.genre_id \
        LEFT JOIN ${MEDIA_GEO_RESTRICT_TABLE_NAME} AS mgr \
            ON m.id = mgr.media_id AND mgr.status = 'active' AND mgr.media_type = '${BOOK_MEDIA_TYPE_ID}' \
        LEFT JOIN content_filters_medias AS cfm \
            ON m.id = cfm.media_id AND cfm.media_type = '${BOOK_MEDIA_TYPE_NAME}' \
        LEFT JOIN content_filters AS cf ON cf.id = cfm.filter_id \
        LEFT JOIN media_language AS ml ON ml.media_id = m.id AND ml.media_type = '${BOOK_MEDIA_TYPE_NAME}' \
        LEFT JOIN ma_language AS mal ON mal.id = ml.language_id \
        LEFT JOIN licensors AS l ON l.media_type = '${BOOK_MEDIA_TYPE_NAME}' AND l.id = m.licensor_id \
        LEFT JOIN site_content_filter_exclusions AS scfe \
            ON scfe.content_filter_id = cf.id AND scfe.media_type_id = ${BOOK_MEDIA_TYPE_ID} \
        LEFT JOIN membership_type_site_content_filter_exclusions AS mtscfe \
            ON mtscfe.content_filter_id = cf.id \
        GROUP BY m.id"
    echo "$query"
}

function getQueryForMusicSong()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT 0 AS episode_id, ma.id AS id, ma.id as media_id, m.*, m.id AS song_id, \
            dsp.\`name\` AS data_source_provider_name, \
            '${MUSIC_MEDIA_TYPE_NAME}' AS media_type, \
            ma.title AS album_title, \
            CAST(CONCAT_WS('-', '${MUSIC_MEDIA_TYPE_ID}', ma.id, m.id) AS CHAR) AS _id, \
            (SELECT mgr.restrict_type \
             FROM media_geo_restrict mgr \
             WHERE m.album_id = mgr.media_id AND mgr.status = 'active' AND mgr.media_type = ${MUSIC_MEDIA_TYPE_ID} \
             GROUP BY m.album_id) AS 'restrict.date[]', \
            (SELECT GROUP_CONCAT(DISTINCT mgr.country_code ORDER BY mgr.date_start) \
             FROM media_geo_restrict mgr \
             WHERE m.album_id = mgr.media_id AND mgr.status = 'active' AND mgr.media_type = ${MUSIC_MEDIA_TYPE_ID} \
             GROUP BY m.album_id) AS 'restrict.country_code[]', \
            (SELECT GROUP_CONCAT(mgr.date_start) \
             FROM media_geo_restrict mgr \
             WHERE m.album_id = mgr.media_id AND mgr.status = 'active' AND mgr.media_type = ${MUSIC_MEDIA_TYPE_ID} \
             GROUP By m.album_id) AS 'restrict.date[]', \
            (SELECT GROUP_CONCAT(DISTINCT \`name\`) \
             FROM music_song_artists msa \
             JOIN music_artist ma On (ma.id = msa.artist_id) \
             WHERE msa.music_id = m.album_id GROUP BY m.id) AS 'people.artist[]', \
            (SELECT GROUP_CONCAT(DISTINCT gm.\`name\`) \
             FROM music_genres mg \
             JOIN genre_music gm ON (gm.id = mg.genre_id) \
             WHERE mg.music_id = m.album_id GROUP BY m.album_id) AS 'genre[]', \
            (SELECT DISTINCT region FROM music_files WHERE music_id = m.id AND region = 'CA') AS 'restrict.song.contry_code[]' \
            FROM music m \
            JOIN music_album AS ma ON m.album_id = ma.id \
            LEFT JOIN ${MUSIC_SCORES} AS mss \
                ON mss.id = ma.id AND mss.device_type_id = ${DEFAULT_DEVICE_ID} \
            LEFT JOIN data_source_provider AS dsp ON dsp.id = ma.data_source_provider_id \
            WHERE m.id >= ${offset} AND m.id < ${batchSize}"
    echo "$query" 
}

function getQueryForMusicAlbum()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT 0 AS episode_id, \
            CAST(CONCAT('${MUSIC_MEDIA_TYPE_ID}', '-', m.id) AS CHAR) AS _id, \
            music_label.\`name\` AS 'labelName[]', \
            COUNT(DISTINCT music.id) AS song_count, \
            l.status AS licensor_status, \
            l.is_public, \
            l.name AS licensor_name, \
            mgr.restrict_type AS 'restrict.type', \
            GROUP_CONCAT(DISTINCT mgr.country_code ORDER BY mgr.date_start) AS 'restrict.country_code[]', \
            CAST(GROUP_CONCAT(mgr.date_start) AS CHAR) AS 'restrict.date[]', \
            '${MUSIC_MEDIA_TYPE_NAME}' AS media_type, \
            m.id as media_id, m.*, \
            GROUP_CONCAT(DISTINCT ma.\`name\`) AS 'people.artist[]', \
            GROUP_CONCAT(DISTINCT gm.\`name\`) AS 'genre[]', \
            dsp.\`name\` AS data_source_provider_name, \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            GROUP_CONCAT(DISTINCT scfe.site_id) AS 'site_exclusion_id[]', \
            GROUP_CONCAT(DISTINCT mal.\`name\`) AS 'languages[]', \
            CAST(GROUP_CONCAT(CONCAT(mtscfe.membership_type_id, '-', mtscfe.site_id)) AS CHAR) \
             AS 'membership_type_site_exclusion_id[]', \
            (SELECT mss.total_score FROM ${MUSIC_SCORES} mss WHERE mss.device_type_id = ${PC_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${PC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${MUSIC_SCORES} mss WHERE mss.device_type_id = ${MOBILE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MOBILE_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${MUSIC_SCORES} mss WHERE mss.device_type_id = ${TABLET_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${TABLET_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${MUSIC_SCORES} mss WHERE mss.device_type_id = ${MAC_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MAC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${MUSIC_SCORES} mss WHERE mss.device_type_id = ${CONSOLE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${CONSOLE_DEVICE_TYPE_NAME}' \
        FROM (SELECT * FROM music_album WHERE id >= ${offset} AND id < ${batchSize}) AS m \
        LEFT JOIN music_album_artists AS maa ON m.id = maa.album_id \
        LEFT JOIN music_artist AS ma ON ma.id = maa.artist_id \
        LEFT JOIN music_album_genres AS mag ON mag.album_id = m.id \
        LEFT JOIN genre_music AS gm ON gm.id = mag.genre_id \
        LEFT JOIN data_source_provider AS dsp ON dsp.id = m.data_source_provider_id \
        LEFT JOIN ${MEDIA_GEO_RESTRICT_TABLE_NAME} AS mgr \
            ON m.id = mgr.media_id AND mgr.status = 'active' \
            AND mgr.media_type = ${MUSIC_MEDIA_TYPE_ID} \
        LEFT JOIN content_filters_medias AS cfm ON m.id = cfm.media_id AND cfm.media_type = '${MUSIC_MEDIA_TYPE_NAME}' \
        LEFT JOIN content_filters cf ON cf.id = cfm.filter_id \
        LEFT JOIN media_language AS ml ON ml.media_id = m.id AND ml.media_type = '${MUSIC_MEDIA_TYPE_NAME}' \
        LEFT JOIN ma_language AS mal ON mal.id = ml.language_id \
        LEFT JOIN licensors AS l ON l.media_type = '${MUSIC_MUSIC_MEDIA_TYPE_NAME}' AND l.id = m.licensor_id \
        LEFT JOIN music AS music ON music.album_id = m.id \
        LEFT JOIN music_label AS music_label ON music_label.id = m.label_id \
        LEFT JOIN site_content_filter_exclusions AS scfe \
            ON scfe.content_filter_id = cf.id AND scfe.media_type_id = ${MUSIC_MEDIA_TYPE_ID} \
        LEFT JOIN membership_type_site_content_filter_exclusions AS mtscfe \
            ON mtscfe.content_filter_id = cf.id \
        GROUP BY m.id"
    echo "$query"
}

function getQueryForMovie()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT m.*, \
            CAST(CONCAT('${MOVIE_MEDIA_TYPE_ID}', '-', m.id) AS CHAR) AS _id, \
            l.status AS licensor_status, mgr.restrict_type AS 'restrict.type', \
            l.is_public, \
            l.name AS licensor_name, \
            GROUP_CONCAT(DISTINCT mgr.country_code ORDER BY mgr.date_start) AS 'restrict.country_code[]', \
            CAST(GROUP_CONCAT(mgr.date_start) AS CHAR) AS 'restrict.date[]', \
            '${MOVIE_MEDIA_TYPE_NAME}' AS media_type, \
            m.id AS media_id, \
            GROUP_CONCAT(DISTINCT ac.\`name\`) AS 'people.actor[]', \
            GROUP_CONCAT(DISTINCT di.\`name\`) AS 'people.director[]', \
            GROUP_CONCAT(DISTINCT pr.\`name\`) AS 'people.producer[]', \
            GROUP_CONCAT(DISTINCT wr.\`name\`) AS 'people.writer[]', \
            GROUP_CONCAT(DISTINCT gm.\`name\`) AS 'genre[]', \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            GROUP_CONCAT(DISTINCT mal.\`name\`) AS 'languages[]', \
            GROUP_CONCAT(DISTINCT scfe.site_id) AS 'site_exclusion_id[]', \
            bc.brightcove_id, bc.non_drm_brightcove_id, \
            CAST(GROUP_CONCAT(CONCAT(mtscfe.membership_type_id, '-', mtscfe.site_id)) AS CHAR) \
             AS 'membership_type_site_exclusion_id[]', \
            (SELECT mss.total_score FROM ${MOVIE_SCORES} mss WHERE mss.device_type_id = ${PC_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${PC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${MOVIE_SCORES} mss WHERE mss.device_type_id = ${MOBILE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MOBILE_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${MOVIE_SCORES} mss WHERE mss.device_type_id = ${TABLET_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${TABLET_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${MOVIE_SCORES} mss WHERE mss.device_type_id = ${MAC_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MAC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${MOVIE_SCORES} mss WHERE mss.device_type_id = ${CONSOLE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${CONSOLE_DEVICE_TYPE_NAME}' \
        FROM (SELECT * FROM movie WHERE id >= ${offset} AND id < ${batchSize}) AS m \
        LEFT JOIN movie_actors AS ma ON m.id = ma.movie_id \
        LEFT JOIN actors AS ac ON ac.id = ma.actor_id \
        LEFT JOIN movie_directors AS md ON md.movie_id = m.id \
        LEFT JOIN directors AS di ON di.id = md.director_id \
        LEFT JOIN movie_producers AS mp ON mp.movie_id = m.id \
        LEFT JOIN producers AS pr ON pr.id = mp.producer_id \
        LEFT JOIN movie_writers AS mw ON mw.movie_id = m.id \
        LEFT JOIN writers AS wr ON wr.id = mw.writer_id \
        LEFT JOIN movie_genres AS mg ON mg.movie_id = m.id \
        LEFT JOIN genre_movie AS gm ON gm.id = mg.genre_id \
        LEFT JOIN ${MEDIA_GEO_RESTRICT_TABLE_NAME} AS mgr \
            ON m.id = mgr.media_id AND mgr.status = 'active' AND mgr.media_type = ${MOVIE_MEDIA_TYPE_ID} \
        LEFT JOIN content_filters_medias AS cfm ON m.id = cfm.media_id AND cfm.media_type = '${MOVIE_MEDIA_TYPE_NAME}' \
        LEFT JOIN content_filters cf ON cf.id = cfm.filter_id \
        LEFT JOIN media_language AS ml On ml.media_id = m.id AND ml.media_type = '${MOVIE_MEDIA_TYPE_NAME}' \
        LEFT JOIN ma_language AS mal ON mal.id = ml.language_id \
        LEFT JOIN licensors AS l ON l.media_type = '${MOVIE_MEDIA_TYPE_NAME}' AND l.id = m.licensor_id \
        LEFT JOIN brightcove AS bc ON bc.status = 'active'  AND bc.id = m.id \
        LEFT JOIN site_content_filter_exclusions AS scfe \
            ON scfe.content_filter_id = cf.id AND scfe.media_type_id = ${MOVIE_MEDIA_TYPE_ID} \
        LEFT JOIN membership_type_site_content_filter_exclusions AS mtscfe \
            ON mtscfe.content_filter_id = cf.id \
        GROUP BY m.id"

    echo "$query"
}

function getQueryForGame()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT 0 AS episode_id, \
            CAST(CONCAT('${GAME_MEDIA_TYPE_ID}', '-', m.id) AS CHAR) AS _id, \
            l.status AS licensor_status, \
            l.is_public, \
            l.name AS licensor_name, \
            mgr.restrict_type AS 'restrict.type', \
            GROUP_CONCAT(DISTINCT mgr.country_code ORDER BY mgr.date_start) AS 'restrict.country_code[]', \
            CAST(GROUP_CONCAT(mgr.date_start) AS CHAR) AS 'restrict.date[]', \
            '${GAME_MEDIA_TYPE_NAME}' AS media_type, \
            m.id AS media_id, m.*, \
            GROUP_CONCAT(DISTINCT de.\`name\`) AS 'people.developer[]', \
            GROUP_CONCAT(DISTINCT gy.\`CategoryName\`) AS 'category.name[]', \
            GROUP_CONCAT(DISTINCT gy.\`OS\`) AS 'category.os[]', \
            GROUP_CONCAT(DISTINCT gga.\`name\`) AS 'genre[]', \
            CAST(GROUP_CONCAT(DISTINCT gt.type_id) AS CHAR) AS 'game_type[]', \
            GROUP_CONCAT(DISTINCT ts.\`name\`) AS 'game_type_name[]', \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            CAST(GROUP_CONCAT(DISTINCT scfe.site_id) AS CHAR) AS 'site_exclusion_id[]', \
            IF(gy.game_id IS NULL, 0, 1) AS is_yummy, \
            GROUP_CONCAT(DISTINCT mal.\`name\`) AS 'languages[]', \
            CAST(GROUP_CONCAT(CONCAT(mtscfe.membership_type_id, '-', mtscfe.site_id)) AS CHAR) \
             AS 'membership_type_site_exclusion_id[]', \
            (SELECT mss.total_score FROM ${GAME_SCORES} mss WHERE mss.device_type_id = ${PC_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${PC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${GAME_SCORES} mss WHERE mss.device_type_id = ${MOBILE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MOBILE_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${GAME_SCORES} mss WHERE mss.device_type_id = ${TABLET_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${TABLET_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${GAME_SCORES} mss WHERE mss.device_type_id = ${MAC_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MAC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${GAME_SCORES} mss WHERE mss.device_type_id = ${CONSOLE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${CONSOLE_DEVICE_TYPE_NAME}' \
        FROM (SELECT * FROM game WHERE id >= ${offset} AND id < ${batchSize}) AS m \
        LEFT JOIN developer AS de ON m.developer_id = de.id \
        LEFT JOIN game_genres AS gg ON gg.game_id = m.id \
        LEFT JOIN genre AS gga ON gga.id = gg.genre_id \
        LEFT JOIN game_yummy AS gy ON m.id = gy.game_id \
        LEFT JOIN game_types AS gt ON gt.game_id = m.id \
        LEFT JOIN types AS ts ON ts.id = gt.type_id \
        LEFT JOIN ${MEDIA_GEO_RESTRICT_TABLE_NAME} AS mgr \
            ON m.id = mgr.media_id AND mgr.status = 'active' AND mgr.media_type = ${GAME_MEDIA_TYPE_ID} \
        LEFT JOIN content_filters_medias AS cfm ON m.id = cfm.media_id AND cfm.media_type = '${GAME_MEDIA_TYPE_NAME}' \
        LEFT JOIN content_filters cf ON cf.id = cfm.filter_id \
        LEFT JOIN media_language AS ml On ml.media_id = m.id AND ml.media_type = '${GAME_MEDIA_TYPE_NAME}' \
        LEFT JOIN ma_language AS mal ON mal.id = ml.language_id \
        LEFT JOIN licensors AS l ON l.media_type = '${GAME_MEDIA_TYPE_NAME}' AND l.id = m.licensor_id \
        LEFT JOIN site_content_filter_exclusions AS scfe \
            ON scfe.content_filter_id = cf.id AND scfe.media_type_id = ${GAME_MEDIA_TYPE_ID} \
        LEFT JOIN membership_type_site_content_filter_exclusions AS mtscfe \
            ON mtscfe.content_filter_id = cf.id \
        GROUP BY m.id"
    echo "$query"
}

function getQueryForSoftware()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT 0 AS episode_id, \
            CAST(CONCAT('${SOFTWARE_MEDIA_TYPE_ID}', '-', m.id) AS CHAR) AS _id, \
            l.status AS licensor_status, \
            l.is_public, \
            l.name AS licensor_name, \
            mgr.restrict_type AS 'restrict.type', \
            GROUP_CONCAT(DISTINCT mgr.country_code ORDER BY mgr.date_start) AS 'restrict.country_code[]', \
            CAST(GROUP_CONCAT(mgr.date_start) AS CHAR) AS 'restrict.date[]', \
            '${SOFTWARE_MEDIA_TYPE_NAME}' AS media_type, \
            m.id AS media_id, m.*, \
            GROUP_CONCAT(DISTINCT m.platform) AS 'category', \
            GROUP_CONCAT(DISTINCT st.\`name\`) AS 'people.softwareType[]', \
            GROUP_CONCAT(DISTINCT st_platform.\`name\`) AS 'software_platform[]', \
            GROUP_CONCAT(DISTINCT sc.\`name\`) AS 'genre[]', \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            CAST(GROUP_CONCAT(DISTINCT scfe.site_id) AS CHAR) AS 'site_exclusion_id[]', \
            GROUP_CONCAT(DISTINCT mal.\`name\`) AS 'languages[]', \
            CAST(GROUP_CONCAT(CONCAT(mtscfe.membership_type_id, '-', mtscfe.site_id)) AS CHAR) \
             AS 'membership_type_site_exclusion_id[]', \
            (SELECT mss.total_score FROM ${SOFTWARE_SCORES} mss WHERE mss.device_type_id = ${PC_DEVICE_TYPE_ID} \
             AND mss.id = m.id) \
             AS 'sorting_score.${PC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${SOFTWARE_SCORES} mss WHERE mss.device_type_id = ${MOBILE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MOBILE_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${SOFTWARE_SCORES} mss WHERE mss.device_type_id = ${TABLET_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${TABLET_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${SOFTWARE_SCORES} mss WHERE mss.device_type_id = ${MAC_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MAC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${SOFTWARE_SCORES} mss WHERE mss.device_type_id = ${CONSOLE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${CONSOLE_DEVICE_TYPE_NAME}' \
        FROM (SELECT * FROM software WHERE id >= ${offset} AND id < ${batchSize}) AS m \
        LEFT JOIN software_software_category AS ssc ON ssc.software_id = m.id \
        LEFT JOIN software_category AS sc ON sc.id = ssc.software_category_id \
        LEFT JOIN software_types AS sts ON m.id = sts.software_id \
        LEFT JOIN software_type AS st ON st.id = sts.type_id \
        LEFT JOIN software_software_type AS sst ON sst.software_id = m.id \
        LEFT JOIN software_type AS st_platform ON sst.software_type_id = st_platform.id \
        LEFT JOIN ${MEDIA_GEO_RESTRICT_TABLE_NAME} AS mgr \
            ON m.id = mgr.media_id AND mgr.status = 'active' AND mgr.media_type = ${SOFTWARE_MEDIA_TYPE_ID} \
        LEFT JOIN content_filters_medias AS cfm ON m.id = cfm.media_id \
            AND cfm.media_type = '${SOFTWARE_MEDIA_TYPE_NAME}' \
        LEFT JOIN content_filters cf ON cf.id = cfm.filter_id \
        LEFT JOIN media_language AS ml On ml.media_id = m.id AND ml.media_type = '${SOFTWARE_MEDIA_TYPE_NAME}' \
        LEFT JOIN ma_language AS mal ON mal.id = ml.language_id \
        LEFT JOIN licensors AS l ON l.media_type = '${SOFTWARE_MEDIA_TYPE_NAME}' AND l.id = m.licensor_id \
        LEFT JOIN site_content_filter_exclusions AS scfe \
            ON scfe.content_filter_id = cf.id AND scfe.media_type_id = ${SOFTWARE_MEDIA_TYPE_ID} \
        LEFT JOIN membership_type_site_content_filter_exclusions AS mtscfe \
            ON mtscfe.content_filter_id = cf.id \
        GROUP BY m.id"

    echo "$query"
}

function getQueryForAudioBook()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT 0 AS episode_id, \
            CAST(CONCAT('${AUDIO_BOOK_MEDIA_TYPE_ID}', '-', m.id) AS CHAR) AS _id, \
            l.status AS licensor_status, \
            l.is_public, \
            l.name AS licensor_name, \
            GROUP_CONCAT(DISTINCT au.\`name\`) AS 'people.author[]', \
            GROUP_CONCAT(DISTINCT nar.\`name\`) AS 'people.narrators[]', \
            GROUP_CONCAT(DISTINCT gb.\`name\`) AS 'genre[]', \
            GROUP_CONCAT(DISTINCT awa.\`name\`) AS 'awards[]', \
            GROUP_CONCAT(DISTINCT seab.\`title\`) AS 'series_title[]', \
            mgr.restrict_type AS 'restrict.type', \
            GROUP_CONCAT(DISTINCT mgr.country_code ORDER BY mgr.date_start) AS 'restrict.country_code[]', \
            CAST(GROUP_CONCAT(mgr.date_start) AS CHAR) AS 'restrict.date[]', \
            '${AUDIO_BOOK_MEDIA_TYPE_NAME}' AS media_type, \
            CAST(m.id AS CHAR) AS media_id, \
            m.*, \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            CAST(GROUP_CONCAT(DISTINCT scfe.site_id) AS CHAR) AS 'site_exclusion_id[]', \
            GROUP_CONCAT(DISTINCT mal.\`name\`) AS 'languages[]', \
            CAST(GROUP_CONCAT(CONCAT(mtscfe.membership_type_id, '-', mtscfe.site_id)) AS CHAR) \
             AS 'membership_type_site_exclusion_id[]', \
            cab.duration AS 'chapter[duration]', \
            cab.part_number AS 'chapter[part_number]', \
            cab.chapter_number AS 'chapter[charter_number]', \
            (SELECT mss.total_score FROM ${AUDIO_BOOK_SCORES} mss WHERE mss.device_type_id = ${PC_DEVICE_TYPE_ID} \
             AND mss.id = m.id) \
             AS 'sorting_score.${PC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${AUDIO_BOOK_SCORES} mss WHERE mss.device_type_id = ${MOBILE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MOBILE_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${AUDIO_BOOK_SCORES} mss WHERE mss.device_type_id = ${TABLET_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${TABLET_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${AUDIO_BOOK_SCORES} mss WHERE mss.device_type_id = ${MAC_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${MAC_DEVICE_TYPE_NAME}', \
            (SELECT mss.total_score FROM ${AUDIO_BOOK_SCORES} mss WHERE mss.device_type_id = ${CONSOLE_DEVICE_TYPE_ID} \
             AND mss.id = m.id ) \
             AS 'sorting_score.${CONSOLE_DEVICE_TYPE_NAME}' \
        FROM (SELECT * FROM audio_book WHERE seq_id >= ${offset} AND seq_id < ${batchSize}) AS m \
        LEFT JOIN ${MEDIA_GEO_RESTRICT_TABLE_NAME} AS mgr \
            ON m.id = mgr.media_id AND mgr.status = 'active' AND mgr.media_type = ${AUDIO_BOOK_MEDIA_TYPE_ID} \
        LEFT JOIN content_filters_medias AS cfm ON m.id = cfm.media_id \
            AND cfm.media_type = '${AUDIO_BOOK_MEDIA_TYPE_NAME}' \
        LEFT JOIN content_filters cf ON cf.id = cfm.filter_id \
        LEFT JOIN audio_book_authors AS aba ON aba.audio_book_id = m.id \
        LEFT JOIN author AS au ON au.id = aba.author_id \
        LEFT JOIN audio_book_narrators AS abn ON abn.audio_book_id = m.id
        LEFT JOIN narrators AS nar ON nar.id = abn.narrator_id
        LEFT JOIN audio_book_genres AS abg ON abg.audio_book_id = m.id \
        LEFT JOIN genre_book AS gb ON gb.id = abg.genre_id \
        LEFT JOIN audio_book_awards AS abaw ON abaw.audio_book_id = m.id \
        LEFT JOIN awards AS awa ON awa.id = abaw.award_id \
        LEFT JOIN audio_book_series AS abse ON abse.audio_book_id = m.id \
        LEFT JOIN series_audio_book AS seab ON seab.id = abse.serie_id \
        LEFT JOIN chapter_audio_book AS cab ON cab.audio_book_id = m.id \
        LEFT JOIN media_language AS ml On ml.media_id = m.id AND ml.media_type = '${AUDIO_BOOK_MEDIA_TYPE_NAME}' \
        LEFT JOIN ma_language AS mal ON mal.id = ml.language_id \
        LEFT JOIN licensors AS l ON l.media_type = '${AUDIO_BOOK_MEDIA_TYPE_NAME}' AND l.id = m.licensor_id \
        LEFT JOIN site_content_filter_exclusions AS scfe \
            ON scfe.content_filter_id = cf.id AND scfe.media_type_id = ${AUDIO_BOOK_MEDIA_TYPE_ID} \
        LEFT JOIN membership_type_site_content_filter_exclusions AS mtscfe \
            ON mtscfe.content_filter_id = cf.id \
        GROUP BY m.id, cab.chapter_number"

    echo "$query"
}
