#!/bin/bash

export PGSERVICE=${PG_SERVICE}

# TODO check hardcoded schema name
REGIONS=`psql -t -c "SELECT name FROM meta.spatialfilter;"`

for REGION in ${REGIONS}
do
    echo "processing region: ${REGION}"
    psql -t -c "SELECT public.export_parking_geojson('${REGION}'::text);" -o /config/export/region_${REGION}.geojson
done
