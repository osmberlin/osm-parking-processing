#!/bin/bash

if [ -z "${PG_ENV_POSTGRES_PASSWORD}" ] \
    || [ -z "${PG_ENV_POSTGRES_DB}" ] \
    || [ -z "${PG_ENV_POSTGRES_USER}" ] \
    || [ -z "${PG_PORT_5432_TCP_ADDR}" ] \
    || [ -z "${PG_PORT_5432_TCP_PORT}" ] ; then
    echo "missing Progress settings"

cat <<EOF
PG_PORT_5432_TCP_ADDR=${PG_PORT_5432_TCP_ADDR}
PG_PORT_5432_TCP_PORT=${PG_PORT_5432_TCP_PORT}
PG_ENV_POSTGRES_DB=${PG_ENV_POSTGRES_DB}
PG_ENV_POSTGRES_USER=${PG_ENV_POSTGRES_USER}
PG_ENV_POSTGRES_PASSWORD=${PG_ENV_POSTGRES_PASSWORD}
PG_SCHEMA_IMPORT=${PG_SCHEMA_IMPORT}
PG_SCHEMA_META=${PG_SCHEMA_META}
PG_SCHEMA_MIDDLE=${PG_SCHEMA_MIDDLE}
PG_OSM2PGSQL_DIFFSIZE=${PG_OSM2PGSQL_DIFFSIZE}
PGSERVICE=${PG_SERVICE}
EOF
exit 1
fi

export PGSERVICE=${PG_SERVICE}

O2P_DIRECTORY=/usr/local/bin/

function importosm () {

    PBF_MERGED_FILENAME=merged.osm.pbf
    PBF_UPTODATE_FILENAME=uptodate.osm.pbf

    if [ -f "/data/${PBF_MERGED_FILENAME}" ] ; then
        rm -f "/data/${PBF_MERGED_FILENAME}"
    fi

    if [ -f "/data/${PBF_UPTODATE_FILENAME}" ] ; then
        rm -f "/data/${PBF_UPTODATE_FILENAME}"
    fi

    #TODO check file size and warn about it

    echo "merging all present osm pbf files"
    echo osmium merge -o /data/${PBF_MERGED_FILENAME} "/osm"/*.pbf
    #TODO output more information like which files, timestamp
    osmium merge -o /data/${PBF_MERGED_FILENAME} "/osm"/*.pbf

    #TODO output current timestamp, updated timestamp
    if [ ! -f "/data/${PBF_UPTODATE_FILENAME}" ] ; then
        osmium fileinfo "/data/${PBF_MERGED_FILENAME}"
        pyosmium-up-to-date \
            --outfile "/data/${PBF_UPTODATE_FILENAME}" \
            --ignore-osmosis-headers \
            --server https://planet.osm.org/replication/minute/ \
            /data/${PBF_MERGED_FILENAME}
        osmium fileinfo "/data/${PBF_UPTODATE_FILENAME}"
        echo "finished updating merged osm data"
    fi

    PG_SCHEMA_EXISTS=$(psql -XAt -c "SELECT EXISTS (SELECT FROM information_schema.schemata WHERE schema_name = '${PG_SCHEMA_IMPORT}');")

    if [ ! "${PG_SCHEMA_EXISTS}" = "t" ]
    then
        echo "create schema PG_SCHEMA_IMPORT"
        psql \
          -c "CREATE SCHEMA IF NOT EXISTS ${PG_SCHEMA_IMPORT} AUTHORIZATION ${PG_ENV_POSTGRES_USER};"
    fi

    echo "run osm import"

    psql \
      -c "CREATE SCHEMA IF NOT EXISTS ${PG_SCHEMA_MIDDLE} AUTHORIZATION ${PG_ENV_POSTGRES_USER};"
    ${O2P_DIRECTORY}osm2pgsql \
        --create \
        --slim \
        --cache 2000 \
        --output=flex \
        --style=/config/parkraum.lua \
        --middle-schema="${PG_SCHEMA_MIDDLE}" \
        "/data/${PBF_UPTODATE_FILENAME}"

    ${O2P_DIRECTORY}osm2pgsql-replication init \
      --middle-schema="${PG_SCHEMA_MIDDLE}" \
      --server https://planet.osm.org/replication/minute/

    echo "current replication status: "
    ${O2P_DIRECTORY}osm2pgsql-replication status --middle-schema="${PG_SCHEMA_MIDDLE}"

    echo "run spatial filter after import"
    /bin/bash /config/run_spatialfilter.sh
}

function updateosm () {

    echo "run OSM update"
    ${O2P_DIRECTORY}osm2pgsql-replication update \
      --middle-schema="${PG_SCHEMA_MIDDLE}" \
      --max-diff-size "$PG_OSM2PGSQL_DIFFSIZE" \
      --post-processing /config/run_spatialfilter.sh \
      -- -O flex -S /config/parkraum.lua \
      || return $?

    echo "current replication status: "
    ${O2P_DIRECTORY}osm2pgsql-replication status --middle-schema="${PG_SCHEMA_MIDDLE}"

}

function import_spatialfilter () {

    PG_SCHEMA_EXISTS=$(psql -XAt -c "SELECT EXISTS (SELECT FROM information_schema.schemata WHERE schema_name = '${PG_SCHEMA_META}');")

    if [ ! "${PG_SCHEMA_EXISTS}" = "t" ]
    then
        echo "create schema ${PG_SCHEMA_META}"
        psql \
          -c "CREATE SCHEMA IF NOT EXISTS ${PG_SCHEMA_META} AUTHORIZATION ${PG_ENV_POSTGRES_USER};"
    fi

    #TODO inform when there is no filter
    for GEOJSONFILE in "/data"/*.geojson
    do
        echo "processing geojson file: ${GEOJSONFILE}"
        PG_TABLE_SPATIALFILTER_EXISTS=$(psql -XAt -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname = '${PG_SCHEMA_META}' AND tablename = 'spatialfilter');")
        LAYERNAME=$(basename "${GEOJSONFILE}" .geojson)

        if [ ! "${PG_TABLE_SPATIALFILTER_EXISTS}" = "t" ]
        then
            echo "create spatial filter table"
            #echo ogr2ogr -lco GEOMETRY_NAME=geom -lco SCHEMA="${PG_SCHEMA_META}" -nlt PROMOTE_TO_MULTI -nln spatialfilter -sql "SELECT '${LAYERNAME}' AS name FROM ${LAYERNAME}" -f "PostgreSQL" PG:service="${PG_SERVICE}" "${GEOJSONFILE}"
            ogr2ogr \
              -lco GEOMETRY_NAME=geom \
              -lco SCHEMA="${PG_SCHEMA_META}" \
              -nlt PROMOTE_TO_MULTI \
              -nln spatialfilter \
              -sql "SELECT '${LAYERNAME}' AS name FROM ${LAYERNAME}" \
              -f "PostgreSQL" PG:service="${PG_SERVICE}" \
              "${GEOJSONFILE}"
            rm "${GEOJSONFILE}"
        else
            echo "append spatial filter table"
            ogr2ogr \
              -nlt PROMOTE_TO_MULTI \
              -append \
              -sql "SELECT '${LAYERNAME}' AS name FROM ${LAYERNAME}" \
              -nln "${PG_SCHEMA_META}".spatialfilter \
              -f "PostgreSQL" PG:service="${PG_SERVICE}" \
              "${GEOJSONFILE}"
            rm "${GEOJSONFILE}"
        fi
    done
    echo "import spatial filter done"
}

while : ; do

    if [ ! $(find /data/ -name "*.geojson" | wc -l) -eq 0 ] ; then
      echo "importing spatialfilter..."
      import_spatialfilter
    fi

    if [ ! $(psql -t -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname = '${PG_SCHEMA_IMPORT}' AND tablename = 'highways');") = "t" ] ; then
      echo "starting import..."
      importosm
    fi

    updateosm
    [ "$LOOP" -eq 0 ] && exit $?
    sleep "$LOOP" || exit
done
