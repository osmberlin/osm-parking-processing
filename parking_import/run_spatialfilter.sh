#!/bin/bash

if [ -z "$PG_ENV_POSTGRES_PASSWORD" ] \
    || [ -z "$PG_ENV_POSTGRES_DB" ] \
    || [ -z "$PG_ENV_POSTGRES_USER" ] \
    || [ -z "$PG_PORT_5432_TCP_ADDR" ] \
    || [ -z "$PG_PORT_5432_TCP_PORT" ] ; then
    echo "missing Progress settings"

cat <<EOF
PG_PORT_5432_TCP_ADDR=$PG_PORT_5432_TCP_ADDR
PG_PORT_5432_TCP_PORT=$PG_PORT_5432_TCP_PORT
PG_ENV_POSTGRES_DB=$PG_ENV_POSTGRES_DB
PG_ENV_POSTGRES_USER=$PG_ENV_POSTGRES_USER
PG_ENV_POSTGRES_PASSWORD=$PG_ENV_POSTGRES_PASSWORD
PG_SCHEMA_META=$PG_SCHEMA_META
PG_SCHEMA_IMPORT=$PG_SCHEMA_IMPORT
PG_SCHEMA_PROCESSING=PG_SCHEMA_PROCESSING
EOF
exit 1
fi

export PGSERVICE=${PG_SERVICE}

SCHEMAOK=$(psql -t -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname = '${PG_SCHEMA_META}' AND tablename = 'spatialfilter');")

if [ ${SCHEMAOK} = "t" ]
then
  echo "start spatial filtering"
  psql -f /config/spatialfilter.sql
  psql -f /config/spatialfilter_cleanup.sql
else
  echo "filter is not ok"
fi


