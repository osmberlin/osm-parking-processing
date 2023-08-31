#!/bin/bash

export PGSERVICE=${PGSERVICE}

function processosm () {
    echo "run spatial filter"
    /bin/bash /config/run_spatialfilter.sh

    echo "run processing"

    PG_SCHEMA_PROCESSING_EXISTS=$(psql -XAt -c "SELECT EXISTS (SELECT FROM information_schema.schemata WHERE schema_name = '${PG_SCHEMA_PROCESSING}');")
    if [ ! ${PG_SCHEMA_PROCESSING_EXISTS} = "t" ]
    then
        echo "create schema PG_SCHEMA_PROCESSING"
        psql \
          -c "CREATE SCHEMA IF NOT EXISTS ${PG_SCHEMA_PROCESSING} AUTHORIZATION ${PG_ENV_POSTGRES_USER};"
    else
        echo "schema ${PG_SCHEMA_PROCESSING} already exists"
    fi

    psql -f /config/db_functions.sql
    psql -f /config/process_osm.sql
    psql -f /config/add_comments_timestamp.sql
    psql -f /config/db_functions_post.sql
    bash /config/export_regions.sh
    echo "done processing"
}

while : ; do
    processosm
    [ $LOOP -eq 0 ] && exit $?
    sleep $LOOP || exit
done
