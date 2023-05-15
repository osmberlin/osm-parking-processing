#!/bin/bash

export PGSERVICE=${PGSERVICE}

# TODO check hardcoded schema name
REGIONS=`psql -t -c "SELECT name FROM meta.spatialfilter;"`

for REGION in ${REGIONS}
do
  echo "processing region: ${REGION}"
  for TABLE in parking_segments parking_spaces parking_lanes
  do
    echo "processing table: ${TABLE}"
    mkdir -p /config/export/${REGION}
    psql -t -c "SELECT public.export_parking_geojson('${REGION}'::text);" -o /config/export/summary_${REGION}.geojson
    cp /config/export/summary_${REGION}.geojson /config/export/${REGION}/
    # TODO kept for compatibility, remove later
    cp /config/export/summary_${REGION}.geojson /config/export/${REGION}/region_${REGION}.geojson
    python3 /config/export_data.py --output_file_name /config/export/${REGION}/${TABLE}_${REGION}.gpkg --table_name processing.${TABLE} --region_name ${REGION}
    echo "${TABLE} done"
  done
done
