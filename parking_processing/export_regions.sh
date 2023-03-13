#!/bin/bash

export PGSERVICE=${PG_SERVICE}

# TODO check hardcoded schema name
REGIONS=`psql -t -c "SELECT name FROM meta.spatialfilter;"`

for REGION in ${REGIONS}
do
    echo "processing region: ${REGION}"
    mkdir -p /config/export/${REGION}
    psql -t -c "SELECT public.export_parking_geojson('${REGION}'::text);" -o /config/export/region_${REGION}.geojson
    cp /config/export/region_${REGION}.geojson /config/export/${REGION}/
    ogr2ogr -f GPKG /config/export/${REGION}/parking_segments_${REGION}.gpkg PG:"service='${PG_SERVICE}'" -nln "parking_segments" -sql "SELECT p.* FROM processing.parking_segments p, meta.spatialfilter s WHERE s.name = '${REGION}'::text AND ST_Intersects(p.geog, s.geom::geography)"
    ogr2ogr -f GPKG /config/export/${REGION}/parking_spaces_${REGION}.gpkg PG:"service='${PG_SERVICE}'" -nln "parking_spaces" -sql "SELECT p.* FROM processing.parking_spaces p, meta.spatialfilter s WHERE s.name = '${REGION}'::text AND ST_Intersects((p.geom)::geography, s.geom::geography)"
done
