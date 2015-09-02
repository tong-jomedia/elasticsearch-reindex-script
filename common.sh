
source "${baseDir}/init.sh"

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
            curl -XDELETE $ES_HOST':'$ES_PORT'/_river/river_'$onePreviousIndex'*/'
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
    local keyName=$2
    local query="SELECT max("$keyName") FROM "$tableName";"
    echo "$query"
}

function getImportBySectionQuery()
{
    local mediaType=$1
    local mediaTableName=$2
    local keyName=$3
    local offset=0
    local batchSize=$4
    local limit=$4

    local getMaxIdCheckQuery=$(getMaxIdCheckQuery "$mediaTableName" "$keyName")
    local maxId=$(/usr/bin/mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" -D "$DB_NAME" -e "$getMaxIdCheckQuery" | awk 'NR>1') 

    local allQuery=""
    while [ ${offset} -le ${maxId} ]
    do
        local singleImportQuery=$(getQueryFor${mediaType} $offset $batchSize)

        local tempQuery='{"statement" : "'$singleImportQuery'"},'
        allQuery=$allQuery$tempQuery
        offset=$(($offset+$limit))
        batchSize=$(($offset+$limit))
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

function sendMapping()
{
    local mapping=$1
    local index=$2
    local indexType=$3

    curl -XPUT $ES_HOST':'$ES_PORT'/'$index'/'
    curl -XPUT $ES_HOST':'$ES_PORT'/'$index'/_mapping/'$indexType -d '
    {
        "'$indexType'" : {
            "properties" : {
                '"$mapping"' 
            }
        }
    }'
}



function importMedia()
{
    local mediaTypeName=$1
    local mediaTableName=$2
    local indexName="${ENV_PREFIX}index_${3}_v${nextIndexVersion}" 
    local keyName=$4
    if [ -z "$5" ]; then
        local indexType="media"
    else
        local indexType=$5
    fi


    if [ -z "$6" ]; then
        local batchSize=$LIMIT
    else
        local batchSize=$6
    fi
   
    local query=$(getImportBySectionQuery "$mediaTypeName" "$mediaTableName" "$keyName" "$batchSize")
    local mapping=$(getMapping "$mediaTypeName" "$mediaTableName")

    if [ -z "$5" ]; then
        local indexMapping='
            "'$indexType'" : {
                "properties" : {
                    '"$mapping"' 
                }
            }';
    else
        local indexMapping=$(getPeopleMapping)
    fi

    # sendMapping "$mapping" "$indexName" "$indexType"
    local jsonString='{
        "type" : "jdbc",
        "jdbc" : {
            "url" : "'$JDBC_URL'",
            "user" : "'$DB_USER'",
            "password" : "'$DB_PASS'",
            "index": "'$indexName'",
            "type": "'$indexType'",
            "autocommit": true,
            "maxbulkactions" : 10000,
            "maxconcurrrentbulkactions": 10,
            "fetchsize" : 100,
            "sql" : ['"$query"']
        }
    }'

#            "type_mapping" : {'"$indexMapping"'}
    local riverIndex="${indexName}_${indexType}"
    echo "${jsonString}" | cat > $baseDir'/../tmpData/'$mediaTypeName
#                                "lowercase", 
#                                "keyword_repeat",
#                                "asciifolding",  
#                                "porter_stem", 
#                                "unique_stem",
    curl -XPUT $ES_HOST':'$ES_PORT'/'${indexName}'/' -d ' 
    {
        "settings" : {
             "index": {
                "analysis": {
                    "filter": {
                        "soundex": { 
                            "type":    "phonetic",
                            "encoder": "soundex"
                        },
                        "dbl_metaphone": { 
                            "type":    "phonetic",
                            "encoder": "doublemetaphone"
                        },
                        "unique_stem": {
                            "type": "unique",
                            "only_on_same_position": true 
                        }
                    },
                    "analyzer": {
                        "mix_search": {
                            "tokenizer": "standard",
                            "filter": [
                                "lowercase", 
                                "keyword_repeat",
                                "asciifolding",  
                                "unique_stem",
                                "porter_stem" 
                            ] 
                        }
                    }
                }
            }
        },
        "mappings" : {'"$indexMapping"'}
    }'
    curl -XPUT $ES_HOST':'$ES_PORT'/_river/river_'$riverIndex'/_meta' -d @$baseDir'/../tmpData/'$mediaTypeName

} 
function getMappingForMusicSong()
{
    local mapping='"people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "artist" : {"type": "string"}
                        }
                    },
                    "people_not_analyzed" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "artist" : {"type": "string", index: "not_analyzed"}
                        }
                    },
                    "genre" : {"type": "string", index: "not_analyzed"},
                    "id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "media_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "album_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "label_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "data_origin_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "ma_release_date" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "date_published" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "analyzer_title": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_genre": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },                   
                    "analyzer_content_segments": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "artist" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            }
                        }
                    }
                    '
    echo "$mapping"
}
function getMappingForMusicAlbum()
{
    local mapping='"people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "artist" : {"type": "string"}
                        }
                    },
                    "people_not_analyzed" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "artist" : {"type": "string", index: "not_analyzed"}
                        }
                    },
                    "genre" : {"type": "string", index: "not_analyzed"},
                    "languages" : {"type" : "string"},
                    "language_codes" : {
                        "type" : "string",
                        "index": "not_analyzed"
                    },
                    "id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "membership_type_site_exclusion_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "song_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "media_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "album_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "label_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "data_origin_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "ma_release_date" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "date_published" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "analyzer_title": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_genre": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },                   
                    "analyzer_content_segments": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "artist" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            }
                        }
                    }
                    '
    echo "$mapping"
}

function getMappingForBook()
{
    local mapping='"people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "author" : {"type": "string"},
                            "artist" : {"type": "string"}
                        }
                    },
                    "people_not_analyzed" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "author" : {"type": "string", index: "not_analyzed"},
                            "artist" : {"type": "string", index: "not_analyzed"}
                        }
                    },
                    "genre" : {"type": "string", index: "not_analyzed"},
                    "languages" : {"type" : "string"},
                    "language_codes" : {
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
                    "id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "status" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "membership_type_site_exclusion_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "media_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "isbn" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "ma_release_date" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "date_published" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "analyzer_title": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_genre": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },                   
                    "analyzer_content_segments": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "author" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            },
                            "artist" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            }
                        }
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
                            "actor" : {"type": "string","position_offset_gap": 100 },
                            "director" : {"type": "string"},
                            "producer" : {"type": "string"},
                            "writer" : {"type": "string"}
                        }
                    },
                    "people_not_analyzed" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "actor" : {"type": "string","position_offset_gap": 100, index: "not_analyzed"},
                            "director" : {"type": "string", index: "not_analyzed"},
                            "producer" : {"type": "string", index: "not_analyzed"},
                            "writer" : {"type": "string", index: "not_analyzed"}
                        }
                    },
                    "genre" : {"type": "string", index: "not_analyzed"},
                    "languages" : {"type" : "string"},
                    "language_codes" : {
                        "type" : "string",
                        "index": "not_analyzed"
                    },
                    "membership_type_site_exclusion_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "ma_release_date" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "date_published" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "analyzer_title": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_genre": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },                   
                    "analyzer_content_segments": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "actor" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            },
                            "producer" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            },
                            "director" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            },
                            "writer" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            }
                        }
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
                            "developer" : {"type": "string"}
                        }
                    },
                    "people_not_analyzed" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "developer" : {"type": "string", index: "not_analyzed"}
                        }
                    },
                    "genre" : {"type": "string", index: "not_analyzed"},
                    "game_type" : {
                        "type" : "string",
                        "store" : "yes",
                        "index":"not_analyzed"
                     },
                    "languages" : {"type" : "string"},
                    "language_codes" : {
                        "type" : "string",
                        "index": "not_analyzed"
                    },
                    "membership_type_site_exclusion_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "ma_release_date" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "date_published" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "analyzer_title": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_genre": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },                   
                    "analyzer_content_segments": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "developer" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            }
                        }
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
                            "software_type" : {"type": "string"}
                        }
                    },
                    "people_not_analyzed" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "software_type" : {"type": "string", index: "not_analyzed"}
                        }
                    },
                    "genre" : {"type": "string", index: "not_analyzed"},
                    "languages" : {"type" : "string"},
                    "language_codes" : {
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
                    },
                    "ma_release_date" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "date_published" : {
                        "type": "date",
                        "format" : "dateOptionalTime"
                    },
                    "analyzer_title": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_genre": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },                   
                    "analyzer_content_segments": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "software_type" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            }
                        }
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
                    "people_not_analyzed" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "author" : {"type": "string", index: "not_analyzed"},
                            "narrator" : {"type": "string", index: "not_analyzed"}
                        }
                    },
                    "languages" : {"type" : "string"},
                    "language_codes" : {
                        "type" : "string",
                        "index": "not_analyzed"
                    },
                    "ma_release_date" : {"type" : "date"},
                    "media_id" : {
                        "type" : "string", 
                        "index": "not_analyzed"
                    },
                    "id" : {
                        "type" : "string", 
                        "index": "not_analyzed"
                    },
                    "sorting_score" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "pc" : {"type": "string"}
                        }
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
                    },
                    "analyzer_title": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_genre": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },                   
                    "analyzer_content_segments": {
                        "type": "string",
                        "analyzer": "mix_search"
                    },
                    "analyzer_people" : {
                        "type" : "nested",
                        "include_in_parent" : true,
                        "properties" : {
                            "author" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            },
                            "narrator" : {
                                "type": "string",
                                "analyzer": "mix_search"
                            }
                        }
                    }'
    echo "$mapping"
}

function getPeopleMapping()
{
    local mapping='
        "book_author": {
            "properties" : {
                "people_id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "analyzer_name": {
                    "type": "string",
                    "analyzer": "mix_search"
                }
            }
        },
        "book_artist": {
            "properties" : {
                "people_id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "analyzer_name": {
                    "type": "string",
                    "analyzer": "mix_search"
                }
            }
        },
        "music_album_artist": {
            "properties" : {
                "people_id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "analyzer_name": {
                    "type": "string",
                    "analyzer": "mix_search"
                }
            }
        },
        "music_song_artist": {
            "properties" : {
                "people_id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "analyzer_name": {
                    "type": "string",
                    "analyzer": "mix_search"
                }
            }
        },
        "movie_actor": {
            "properties" : {
                "people_id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "analyzer_name": {
                    "type": "string",
                    "analyzer": "mix_search"
                }
            }
        },
        "movie_writer": {
            "properties" : {
                "people_id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "analyzer_name": {
                    "type": "string",
                    "analyzer": "mix_search"
                }
            }
        },
        "movie_producer": {
            "properties" : {
                "people_id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "analyzer_name": {
                    "type": "string",
                    "analyzer": "mix_search"
                }
            }
        },
        "movie_director": {
            "properties" : {
                "people_id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "analyzer_name": {
                    "type": "string",
                    "analyzer": "mix_search"
                }
            }
        },
        "game_developer": {
            "properties" : {
                "people_id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "id" : {
                    "type": "string",
                    "index": "not_analyzed"
                },
                "analyzer_name": {
                    "type": "string",
                    "analyzer": "mix_search"
                }
            }
        }'

    echo "$mapping"
}

function getMappingForBookAuthor()
{
    local mapping='"people_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '

    echo "$mapping"
}

function getMappingForBookArtist()
{
    local mapping='"people_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '

    echo "$mapping"
}

function getMappingForMusicAlbumArtist()
{
    local mapping='"people_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '

    echo "$mapping"
}


function getMappingForMusicSongArtist()
{
    local mapping='"people_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '

    echo "$mapping"
}

function getMappingForMovieActor()
{
    local mapping='"people_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '

    echo "$mapping"
}

function getMappingForMovieDirector()
{
    local mapping='"people_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '

    echo "$mapping"
}
function getMappingForMovieWriter()
{
    local mapping='"people_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '

    echo "$mapping"
}
function getMappingForMovieProducer()
{
    local mapping='"people_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '

    echo "$mapping"
}

function getMappingForGameDeveloper()
{
    local mapping='"people_id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    },
                    "id" : {
                        "type": "string",
                        "index": "not_analyzed"
                    }
                    '

    echo "$mapping"
}

function getQueryForGameDeveloper()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT CAST(CONCAT('GAME-DEVELOPER', '-', a.id) AS CHAR) AS _id, \
             '${GAME_MEDIA_TYPE_NAME}' AS media_type, 'developer' AS people_type, \
             a.*, a.id AS people_id, maa.status, \
             a.name AS analyzer_name, COUNT(maa.id) AS total_media \
        FROM (SELECT * FROM developer WHERE id >= ${offset} AND id < ${batchSize}) AS a \
        JOIN game AS maa ON a.id = maa.developer_id \
        GROUP BY a.id";
    echo "$query"
}

function getQueryForMovieActor()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT CAST(CONCAT('MOVIE-ACTOR', '-', a.id) AS CHAR) AS _id, \
             '${MOVIE_MEDIA_TYPE_NAME}' AS media_type, 'actor' AS people_type, a.*, a.id AS people_id, \
             a.name AS analyzer_name, COUNT(maa.movie_id) AS total_media \
        FROM (SELECT * FROM actors WHERE id >= ${offset} AND id < ${batchSize}) AS a \
        JOIN movie_actors AS maa ON a.id = maa.actor_id \
        GROUP BY a.id";
    echo "$query"
}

function getQueryForMovieDirector()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT CAST(CONCAT('MOVIE-DIRECTOR', '-', a.id) AS CHAR) AS _id, \
             '${MOVIE_MEDIA_TYPE_NAME}' AS media_type, 'director' AS people_type, a.*, a.id AS people_id, \
             a.name AS analyzer_name, COUNT(maa.movie_id) AS total_media \
        FROM (SELECT * FROM directors WHERE id >= ${offset} AND id < ${batchSize}) AS a \
        JOIN movie_directors AS maa ON a.id = maa.director_id \
        GROUP BY a.id";
    echo "$query"
}

function getQueryForMovieWriter()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT CAST(CONCAT('MOVIE-WRITER', '-', a.id) AS CHAR) AS _id, \
             '${MOVIE_MEDIA_TYPE_NAME}' AS media_type, 'writer' AS people_type, a.*, a.id AS people_id, \
             a.name AS analyzer_name, COUNT(maa.movie_id) AS total_media \
        FROM (SELECT * FROM writers WHERE id >= ${offset} AND id < ${batchSize}) AS a \
        JOIN movie_writers AS maa ON a.id = maa.writer_id \
        GROUP BY a.id";
    echo "$query"
}

function getQueryForMovieProducer()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT CAST(CONCAT('MOVIE-PRODUCER', '-', a.id) AS CHAR) AS _id, \
             '${MOVIE_MEDIA_TYPE_NAME}' AS media_type, 'producer' AS people_type, a.*, a.id AS people_id, \
             a.name AS analyzer_name, COUNT(maa.movie_id) AS total_media \
        FROM (SELECT * FROM producers WHERE id >= ${offset} AND id < ${batchSize}) AS a \
        JOIN movie_producers AS maa ON a.id = maa.producer_id \
        GROUP BY a.id";
    echo "$query"
}



function getQueryForBookAuthor()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT CAST(CONCAT('BOOK_AUTHOR', '-', a.id) AS CHAR) AS _id, \
             '${BOOK_MEDIA_TYPE_NAME}' AS media_type, 'author' AS people_type, a.*, a.id AS people_id, \
             a.name AS analyzer_name, COUNT(maa.book_id) AS total_media \
        FROM (SELECT * FROM author WHERE id >= ${offset} AND id < ${batchSize}) AS a \
        JOIN book_authors AS maa ON a.id = maa.author_id \
        GROUP BY a.id";
    echo "$query"
}

function getQueryForBookArtist()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT CAST(CONCAT('BOOK_ARTSIT', '-', a.id) AS CHAR) AS _id, \
             '${BOOK_MEDIA_TYPE_NAME}' AS media_type, 'artist' AS people_type, a.*, a.id AS people_id, \
             a.name AS analyzer_name, COUNT(maa.book_id) AS total_media \
        FROM (SELECT * FROM artists WHERE id >= ${offset} AND id < ${batchSize}) AS a \
        JOIN book_artists AS maa ON a.id = maa.artist_id \
        GROUP BY a.id";
    echo "$query"
}

function getQueryForMusicAlbumArtist()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT CAST(CONCAT('MUSIC_ALBUM_ARTIST', '-', a.id) AS CHAR) AS _id, \
             '${MUSIC_MEDIA_TYPE_NAME}' AS media_type, 'artist' AS people_type, \
             CAST(a.id AS CHAR) AS id, \
             a.name AS analyzer_name, \
             a.name, \
             a.date_added, \
             a.keyword, \
             a.is_band, \
             a.status, \
             a.data_origin_id, \
             a.data_source_provider_id, \
             a.data_origin_status, \
             CAST(a.id AS CHAR) AS people_id, \
             COUNT(maa.album_id) AS total_media \
        FROM (SELECT * FROM music_album_artists WHERE seq_id >= ${offset} AND seq_id < ${batchSize}) AS maa \
        JOIN music_artist AS a ON a.id = maa.artist_id \
        GROUP BY a.id";
    echo "$query"
}

function getQueryForMusicSongArtist()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT CAST(CONCAT('MUSIC_SONG_ARTIST', '-', a.id) AS CHAR) AS _id, \
             '${MUSIC_SONG_MEDIA_TYPE_NAME}' AS media_type, 'artist' AS people_type, \
             CAST(a.id AS CHAR) AS id, \
             a.name AS analyzer_name, \
             a.name, \
             a.date_added, \
             a.keyword, \
             a.is_band, \
             a.status, \
             a.data_origin_id, \
             a.data_source_provider_id, \
             a.data_origin_status, \
             CAST(a.id AS CHAR) AS people_id, \
             COUNT(maa.music_id) AS total_media \
        FROM (SELECT * FROM music_song_artists WHERE seq_id >= ${offset} AND seq_id < ${batchSize}) AS maa \
        JOIN music_artist AS a ON a.id = maa.artist_id \
        GROUP By a.id";
    echo "$query"
}

function getQueryForAudioBook()
{
    local offset=$1
    local batchSize=$2

    local query="\
        SELECT 0 AS episode_id, \
            CAST(CONCAT('${AUDIO_BOOK_MEDIA_TYPE_ID}', '-', m.id) AS CHAR) AS _id, \
            CAST(m.id AS CHAR) AS id, \
            CAST(m.id AS CHAR) AS media_id, \
            m.seq_id, \
            m.isbn_retail, \
            m.isbn_library, \
            m.title, \
            m.title AS analyzer_title, \
            m.subtitle, \
            m.description, \
            m.description, \
            m.licensor_id, \
            m.data_source_provider_id, \
            m.data_origin_id, \
            m.img_url, \
            m.abridgment, \
            m.size_in_bytes, \
            m.runtime, \
            m.duration, \
            m.copyright_year, \
            m.sample_url, \
            m.grade_level, \
            m.street_date, \
            m.times_bestseller_date, \
            m.common_core, \
            m.chapterized, \
            m.title_acquisition_status, \
            m.metadata_sig, \
            m.status, \
            m.batch_id, \
            m.ma_release_date, \
            m.date_published, \
            '${AUDIO_BOOK_MEDIA_TYPE_NAME}' AS media_type, \
            mgr.restrict_type AS 'restrict.type', \
            l.status AS licensor_status, \
            l.is_public, \
            l.name AS licensor_name, \
            CAST(GROUP_CONCAT(DISTINCT au.id) AS CHAR) AS 'people_id.author[]', \
            CAST(GROUP_CONCAT(DISTINCT nar.id)AS CHAR) AS 'people_id.narrators[]', \
            GROUP_CONCAT(DISTINCT au.\`name\`) AS 'people.author[]', \
            GROUP_CONCAT(DISTINCT nar.\`name\`) AS 'people.narrators[]', \
            GROUP_CONCAT(DISTINCT LOWER(au.\`name\`)) AS 'people_not_analyzed.author[]', \
            GROUP_CONCAT(DISTINCT LOWER(nar.\`name\`)) AS 'people_not_analyzed.narrators[]', \
            GROUP_CONCAT(DISTINCT LOWER(gb.\`name\`)) AS 'genre[]', \
            GROUP_CONCAT(DISTINCT awa.\`name\`) AS 'awards[]', \
            GROUP_CONCAT(DISTINCT seab.\`title\`) AS 'series_title[]', \
            mgr.restrict_type AS 'restrict.type', \
            GROUP_CONCAT(DISTINCT mgr.country_code ORDER BY mgr.date_start) AS 'restrict.country_code[]', \
            CAST(GROUP_CONCAT(mgr.date_start) AS CHAR) AS 'restrict.date[]', \
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
        LEFT JOIN author_audio_book AS au ON au.id = aba.author_id \
        LEFT JOIN audio_book_narrators AS abn ON abn.audio_book_id = m.id
        LEFT JOIN narrator_audio_book AS nar ON nar.id = abn.narrator_id
        LEFT JOIN audio_book_genres AS abg ON abg.audio_book_id = m.id \
        LEFT JOIN genre_audio_book AS gb ON gb.id = abg.genre_id \
        LEFT JOIN audio_book_awards AS abaw ON abaw.audio_book_id = m.id \
        LEFT JOIN award_audio_book AS awa ON awa.id = abaw.award_id \
        LEFT JOIN audio_book_series AS abse ON abse.audio_book_id = m.id \
        LEFT JOIN serie_audio_book AS seab ON seab.id = abse.serie_id \
        LEFT JOIN audio_book_chapter AS cab ON cab.audio_book_id = m.id \
        LEFT JOIN media_language AS ml On ml.media_id = m.id AND ml.media_type = '${AUDIO_BOOK_MEDIA_TYPE_NAME}' \
        LEFT JOIN ma_language AS mal ON mal.id = ml.language_id \
        LEFT JOIN licensors AS l ON l.media_type = '${AUDIO_BOOK_MEDIA_TYPE_NAME}' AND l.id = m.licensor_id \
        LEFT JOIN site_content_filter_exclusions AS scfe \
            ON scfe.content_filter_id = cf.id AND scfe.media_type_id = ${AUDIO_BOOK_MEDIA_TYPE_ID} \
        LEFT JOIN membership_type_site_content_filter_exclusions AS mtscfe \
            ON mtscfe.content_filter_id = cf.id \
        GROUP BY m.seq_id, cab.chapter_number"

    echo "$query"
}

function getQueryForBook()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT  0 AS episode_id, \
            CAST(CONCAT('${BOOK_MEDIA_TYPE_ID}', '-', m.id) AS CHAR) AS _id, \
            CAST(m.id AS CHAR) AS id, \
            CAST(m.id AS CHAR) AS media_id, \
            m.isbn, \
            m.title, \
            m.title AS analyzer_title, \
            m.author, \
            m.description, \
            m.number_of_pages, \
            m.release_year, \
            m.ma_release_date, \
            m.emedia_release_date, \
            m.language, \
            m.date_added, \
            m.premium, \
            m.download_url, \
            m.is_downloadable, \
            m.jpg_download_url, \
            m.licensor_id, \
            m.author_id, \
            m.volume_number, \
            m.issue_number, \
            m.version_number, \
            m.top_book, \
            m.last_viewed, \
            m.total_num_views, \
            m.average_rating, \
            m.total_ratings, \
            m.today, \
            m.today_views, \
            m.tour_views, \
            m.featured, \
            m.featured_ma, \
            m.ma_queue, \
            m.popular, \
            m.new_release, \
            m.status, \
            m.hide, \
            m.keyword, \
            m.usd_price, \
            m.source, \
            m.has_pages_v2, \
            m.jo_score, \
            m.popularity, \
            m.secret, \
            m.file_format_type_id, \
            m.qastatus, \
            m.batch_id, \
            m.num_of_images, \
            m.date_published, \
            '${BOOK_MEDIA_TYPE_NAME}' AS media_type, \
            l.status AS licensor_status, \
            l.is_public, \
            l.name AS licensor_name, \
            (IF (SUBSTRING(download_url, -3) = 'pdf', 0, 1)) AS is_mobile, \
            mgr.restrict_type AS 'restrict.type', \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'analyzer_content_segments[]', \
            GROUP_CONCAT(DISTINCT mgr.country_code ORDER BY mgr.date_start) AS 'restrict.country_code[]', \
            CAST(GROUP_CONCAT(mgr.date_start) AS CHAR) AS 'restrict.date[]', \
            CAST(GROUP_CONCAT(DISTINCT au.\`id\`) AS CHAR) AS 'people_id.author[]', \
            CAST(GROUP_CONCAT(DISTINCT ar.\`id\`) AS CHAR) AS 'people_id.artist[]', \
            GROUP_CONCAT(DISTINCT au.\`name\`) AS 'people.author[]', \
            GROUP_CONCAT(DISTINCT ar.\`name\`) AS 'people.artist[]', \
            GROUP_CONCAT(DISTINCT au.\`name\`) AS 'analyzer_people.author[]', \
            GROUP_CONCAT(DISTINCT ar.\`name\`) AS 'analyzer_people.artist[]', \
            GROUP_CONCAT(DISTINCT LOWER(au.\`name\`)) AS 'people_not_analyzed.author[]', \
            GROUP_CONCAT(DISTINCT LOWER(ar.\`name\`)) AS 'people_not_analyzed.artist[]', \
            GROUP_CONCAT(DISTINCT LOWER(gb.\`name\`)) AS 'genre[]', \
            GROUP_CONCAT(DISTINCT gb.\`name\`) AS 'analyzer_genre[]', \
            GROUP_CONCAT(DISTINCT scfe.site_id) AS 'site_exclusion_id[]', \
            GROUP_CONCAT(DISTINCT mal.\`name\`) AS 'languages[]', \
            GROUP_CONCAT(DISTINCT mal.\`code\`) AS 'language_codes[]', \
            CAST(GROUP_CONCAT(CONCAT(mtscfe.membership_type_id, '-', mtscfe.site_id)) AS CHAR) \
             AS 'membership_type_site_exclusion_id[]', \
            (SELECT GROUP_CONCAT(DISTINCT p.\`name\`) FROM book_publishers AS bp \
             JOIN publishers AS p ON p.id = bp.publisher_id \
             WHERE bp.book_id = m.id) AS 'publisher_name[]', \
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
        FROM (SELECT * FROM book WHERE seq_id >= ${offset} AND seq_id < ${batchSize}) AS m \
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
        SELECT 0 AS episode_id, \
            '1979-01-01' AS ma_release_date, \
            m.status AS licensor_status, \
            CAST(ma.id AS CHAR) AS id, \
            CAST(m.id AS CHAR) as media_id, \
            CAST(m.label_id AS CHAR) AS label_id, \
            CAST(m.album_id AS CHAR) AS album_id, \
            CAST(m.data_origin_id AS CHAR) AS data_origin_id, \
            CAST(m.id AS CHAR) AS song_id, \
            m.title, \
            m.artist_name, \
            m.description, \
            m.release_date, \
            m.date_added, \
            m.premium, \
            m.download_url, \
            m.last_viewed, \
            m.total_num_views, \
            m.average_rating, \
            m.total_ratings, \
            m.today, \
            m.today_views, \
            m.tour_views, \
            m.featured, \
            m.featured_ma, \
            m.top_music, \
            m.popular, \
            m.new_release, \
            m.status, \
            m.publisher, \
            m.hide, \
            m.keyword, \
            m.cd_title, \
            m.cd_description, \
            m.vocals, \
            m.in_style_of, \
            m.category, \
            m.sub_category, \
            m.featured_instruments, \
            m.upc, \
            m.track_length, \
            m.track, \
            m.languages, \
            m.song_type, \
            m.disc, \
            m.sku, \
            m.data_origin_status, \
            m.data_source_provider_id, \
            m.isrc, \
            m.parental_advisory, \
            m.qastatus, \
            m.batch_id, \
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
             (SELECT CAST(GROUP_CONCAT(mgr.date_start) AS CHAR) \
             FROM media_geo_restrict mgr \
             WHERE m.album_id = mgr.media_id AND mgr.status = 'active' AND mgr.media_type = ${MUSIC_MEDIA_TYPE_ID} \
             GROUP By m.album_id) AS 'restrict.date[]', \
            (SELECT GROUP_CONCAT(DISTINCT mar.\`name\`) \
             FROM music_song_artists msa \
             JOIN music_artist mar On (mar.id = msa.artist_id) \
             WHERE msa.music_id = song_id GROUP BY m.id) AS 'people.artist[]', \
             (SELECT GROUP_CONCAT(DISTINCT LOWER(mar.\`name\`)) \
             FROM music_song_artists msa \
             JOIN music_artist mar On (mar.id = msa.artist_id) \
             WHERE msa.music_id = song_id GROUP BY m.id) AS 'people_not_analyzed.artist[]', \
            (SELECT CAST(GROUP_CONCAT(DISTINCT mar.\`id\`) AS CHAR) \
             FROM music_song_artists msa \
             JOIN music_artist mar On (mar.id = msa.artist_id) \
             WHERE msa.music_id = song_id GROUP BY m.id) AS 'people_id.artist[]', \
             (SELECT GROUP_CONCAT(DISTINCT LOWER(gm.\`name\`)) \
             FROM music_genres mg \
             JOIN genre_music gm ON (gm.id = mg.genre_id) \
             WHERE mg.music_id = m.id GROUP BY m.id) AS 'genre[]', \
            (SELECT CAST(GROUP_CONCAT(DISTINCT gm.gracenote_id) AS CHAR) \
             FROM music_genres mg \
             JOIN genre_music gm ON (gm.id = mg.genre_id) \
             WHERE mg.music_id = m.id GROUP BY m.id) AS 'gracenote_id[]', \
            (SELECT GROUP_CONCAT(DISTINCT region) FROM music_files WHERE music_id = m.id) AS 'restrict.song.country_code[]', \
            (SELECT GROUP_CONCAT(CAST(CONCAT_WS('----', mf.music_id, mf.format_id, mf.file, mf.region, mf.batch_id,\
             mfo.format, mfo.bitrate) AS CHAR)) \
             FROM music_files mf JOIN audio_format AS mfo ON mf.format_id = mfo.id WHERE music_id = m.id) AS 'country_available[]' \
            FROM music m \
            JOIN music_album AS ma ON m.album_id = ma.id \
            LEFT JOIN ${MUSIC_SCORES} AS mss \
                ON mss.id = ma.id AND mss.device_type_id = ${DEFAULT_DEVICE_ID} \
            LEFT JOIN data_source_provider AS dsp ON dsp.id = ma.data_source_provider_id \
            WHERE m.seq_id >= ${offset} AND m.seq_id < ${batchSize}"
    echo "$query" 
}

function getQueryForMusicAlbum()
{
    local offset=$1
    local batchSize=$2
    local query="\
        SELECT 0 AS episode_id, \
            CAST(CONCAT('${MUSIC_MEDIA_TYPE_ID}', '-', m.id) AS CHAR) AS _id, \
            CAST(m.id AS CHAR) as id, \
            CAST(m.id AS CHAR) as media_id, \
            CAST(m.label_id AS CHAR) AS label_id, \
            CAST(m.data_origin_id AS CHAR) AS data_origin_id, \
            m.title, \
            m.search_title, \
            m.description, \
            m.release_date, \
            m.ma_release_date, \
            m.date_added, \
            m.premium, \
            m.last_viewed, \
            m.total_num_views, \
            m.average_rating, \
            m.total_ratings, \
            m.today, \
            m.today_views, \
            m.tour_views, \
            m.featured, \
            m.featured_ma, \
            m.ma_queue, \
            m.top_album, \
            m.popular, \
            m.new_release, \
            m.status, \
            m.supplier_id, \
            m.hide, \
            m.keyword, \
            m.genre_id, \
            m.licensor_id, \
            m.format, \
            m.featured_instruments, \
            m.total_listens, \
            m.jo_score, \
            m.popularity, \
            m.data_origin_status, \
            m.data_source_provider_id, \
            m.upc, \
            m.parental_advisory, \
            m.batch_id, \
            m.qastatus, \
            m.num_of_images, \
            m.date_published, \
            l.status AS licensor_status, \
            l.is_public, \
            l.name AS licensor_name, \
            mgr.restrict_type AS 'restrict.type', \
            GROUP_CONCAT(DISTINCT mgr.country_code ORDER BY mgr.date_start) AS 'restrict.country_code[]', \
            CAST(GROUP_CONCAT(mgr.date_start) AS CHAR) AS 'restrict.date[]', \
            '${MUSIC_MEDIA_TYPE_NAME}' AS media_type, \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            GROUP_CONCAT(DISTINCT scfe.site_id) AS 'site_exclusion_id[]', \
            CAST(GROUP_CONCAT(CONCAT(mtscfe.membership_type_id, '-', mtscfe.site_id)) AS CHAR) \
             AS 'membership_type_site_exclusion_id[]', \
            (SELECT music_label.\`name\` FROM music_label AS music_label WHERE music_label.id = m.label_id) AS 'labelName[]', \
            (SELECT COUNT(DISTINCT music.id) FROM music WHERE music.album_id = m.id) AS song_count, \
            (SELECT GROUP_CONCAT(music.title) FROM music WHERE music.album_id = m.id) AS 'music_songs.title[]', \
            (SELECT CAST(GROUP_CONCAT(DISTINCT ma.\`id\`) AS CHAR) FROM music_album_artists AS maa  \
             LEFT JOIN music_artist AS ma ON ma.id = maa.artist_id WHERE m.id = maa.album_id) AS 'people_id.artist[]', \
            (SELECT GROUP_CONCAT(DISTINCT ma.\`name\`) FROM music_album_artists AS maa  \
             LEFT JOIN music_artist AS ma ON ma.id = maa.artist_id WHERE m.id = maa.album_id) AS 'people.artist[]', \
             (SELECT GROUP_CONCAT(DISTINCT LOWER(ma.\`name\`)) FROM music_album_artists AS maa  \
             LEFT JOIN music_artist AS ma ON ma.id = maa.artist_id WHERE m.id = maa.album_id) AS 'people_not_analyzed.artist[]', \
            (SELECT GROUP_CONCAT(DISTINCT ma.\`id\`) FROM music_album_artists AS maa  \
             LEFT JOIN music_artist AS ma ON ma.id = maa.artist_id WHERE m.id = maa.album_id) AS 'people.artist_id[]', \
            (SELECT dsp.\`name\` FROM data_source_provider AS dsp WHERE dsp.id = m.data_source_provider_id) \
             AS data_source_provider_name, \
             (SELECT GROUP_CONCAT(DISTINCT LOWER(gm.\`name\`)) FROM music_album_genres AS mag \
             LEFT JOIN genre_music AS gm ON gm.id = mag.genre_id \
             WHERE mag.album_id = m.id ) AS 'genre[]', \
            (SELECT GROUP_CONCAT(DISTINCT mal.\`name\`) FROM media_language AS ml \
             LEFT JOIN ma_language AS mal ON mal.id = ml.language_id \
             WHERE ml.media_id = m.id AND ml.media_type = '${MUSIC_MEDIA_TYPE_NAME}') AS 'languages[]', \
            (SELECT GROUP_CONCAT(DISTINCT mal.\`name\`) FROM media_language AS ml \
             LEFT JOIN ma_language AS mal ON mal.id = ml.language_id \
             WHERE ml.media_id = m.id AND ml.media_type = '${MUSIC_MEDIA_TYPE_NAME}') AS 'language_codes[]', \
            (SELECT CAST(GROUP_CONCAT(DISTINCT gm.gracenote_id) AS CHAR) \
             FROM music_album_genres mg \
             JOIN genre_music gm ON (gm.id = mg.genre_id) \
             WHERE mg.album_id = m.id GROUP BY m.id) AS 'gracenote_id[]', \
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
        FROM (SELECT * FROM music_album WHERE seq_id >= ${offset} AND seq_id < ${batchSize}) AS m \
        LEFT JOIN ${MEDIA_GEO_RESTRICT_TABLE_NAME} AS mgr \
            ON m.id = mgr.media_id AND mgr.status = 'active' \
            AND mgr.media_type = ${MUSIC_MEDIA_TYPE_ID} \
        LEFT JOIN licensors AS l ON l.media_type = '${MUSIC_MUSIC_MEDIA_TYPE_NAME}' AND l.id = m.licensor_id \
        LEFT JOIN content_filters_medias AS cfm ON m.id = cfm.media_id AND cfm.media_type = '${MUSIC_MEDIA_TYPE_NAME}' \
        LEFT JOIN content_filters cf ON cf.id = cfm.filter_id \
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
            CAST(GROUP_CONCAT(DISTINCT ac.\`id\`) AS CHAR) AS 'people_id.actor[]', \
            CAST(GROUP_CONCAT(DISTINCT di.\`id\`) AS CHAR) AS 'people_id.director[]', \
            CAST(GROUP_CONCAT(DISTINCT pr.\`id\`) AS CHAR) AS 'people_id.producer[]', \
            CAST(GROUP_CONCAT(DISTINCT wr.\`id\`) AS CHAR) AS 'people_id.writer[]', \
            GROUP_CONCAT(DISTINCT ac.\`name\`) AS 'people.actor[]', \
            GROUP_CONCAT(DISTINCT di.\`name\`) AS 'people.director[]', \
            GROUP_CONCAT(DISTINCT pr.\`name\`) AS 'people.producer[]', \
            GROUP_CONCAT(DISTINCT wr.\`name\`) AS 'people.writer[]', \
            GROUP_CONCAT(DISTINCT LOWER(ac.\`name\`)) AS 'people_not_analyzed.actor[]', \
            GROUP_CONCAT(DISTINCT LOWER(di.\`name\`)) AS 'people_not_analyzed.director[]', \
            GROUP_CONCAT(DISTINCT LOWER(pr.\`name\`)) AS 'people_not_analyzed.producer[]', \
            GROUP_CONCAT(DISTINCT LOWER(wr.\`name\`)) AS 'people_not_analyzed.writer[]', \
            GROUP_CONCAT(DISTINCT LOWER(gm.\`name\`)) AS 'genre[]', \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            GROUP_CONCAT(DISTINCT mal.\`name\`) AS 'languages[]', \
            GROUP_CONCAT(DISTINCT mal.\`code\`) AS 'language_codes[]', \
            GROUP_CONCAT(DISTINCT scfe.site_id) AS 'site_exclusion_id[]', \
            bc.brightcove_id, bc.non_drm_brightcove_id, \
            CAST(GROUP_CONCAT(CONCAT(mtscfe.membership_type_id, '-', mtscfe.site_id)) AS CHAR) \
             AS 'membership_type_site_exclusion_id[]', \
            (SELECT GROUP_CONCAT(DISTINCT bms.title) FROM _biz__ma_serie AS bms \
             WHERE bms.movie_id = m.id AND bms.status = 1) AS 'serie_title[]', \
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
            CAST(GROUP_CONCAT(DISTINCT de.\`id\`) AS CHAR) AS 'people_id.developer[]', \
            GROUP_CONCAT(DISTINCT de.\`name\`) AS 'people.developer[]', \
            GROUP_CONCAT(DISTINCT LOWER(de.\`name\`)) AS 'people_not_analyzed.developer[]', \
            GROUP_CONCAT(DISTINCT gy.\`CategoryName\`) AS 'category.name[]', \
            GROUP_CONCAT(DISTINCT gy.\`OS\`) AS 'category.os[]', \
            GROUP_CONCAT(DISTINCT LOWER(gga.\`name\`)) AS 'genre[]', \
            CAST(GROUP_CONCAT(DISTINCT gt.type_id) AS CHAR) AS 'game_type[]', \
            GROUP_CONCAT(DISTINCT ts.\`name\`) AS 'game_type_name[]', \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            CAST(GROUP_CONCAT(DISTINCT scfe.site_id) AS CHAR) AS 'site_exclusion_id[]', \
            IF(gy.game_id IS NULL, 0, 1) AS is_yummy, \
            GROUP_CONCAT(DISTINCT mal.\`name\`) AS 'languages[]', \
            GROUP_CONCAT(DISTINCT mal.\`code\`) AS 'language_codes[]', \
            CAST(GROUP_CONCAT(CONCAT(mtscfe.membership_type_id, '-', mtscfe.site_id)) AS CHAR) \
             AS 'membership_type_site_exclusion_id[]', \
            (SELECT GROUP_CONCAT(s.\`name\`) FROM studio AS s \
             WHERE s.id = m.studio_id) AS 'studio_name[]', \
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
            CAST(GROUP_CONCAT(DISTINCT st.\`id\`) AS CHAR) AS 'people_id.softwareType[]', \
            GROUP_CONCAT(DISTINCT st.\`name\`) AS 'people.softwareType[]', \
            GROUP_CONCAT(DISTINCT LOWER(st.\`name\`)) AS 'people_not_analyzed.softwareType[]', \
            GROUP_CONCAT(DISTINCT st_platform.\`name\`) AS 'software_platform[]', \
            GROUP_CONCAT(DISTINCT LOWER(sc.\`name\`)) AS 'genre[]', \
            GROUP_CONCAT(DISTINCT cf.\`name\`) AS 'content_segments[]', \
            CAST(GROUP_CONCAT(DISTINCT scfe.site_id) AS CHAR) AS 'site_exclusion_id[]', \
            GROUP_CONCAT(DISTINCT mal.\`name\`) AS 'languages[]', \
            GROUP_CONCAT(DISTINCT mal.\`code\`) AS 'language_codes[]', \
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
