--TODO check hardcoded schema names and apply it only after tables exist
CREATE OR REPLACE FUNCTION public.export_parking_geojson(region text)
 RETURNS json
 LANGUAGE sql
AS $function$
    WITH features AS (
        SELECT
            b.id,
            b.name,
            b.admin_level,
            b.area_sqkm,
            b.street_side_km,
            b.lane_km,
            b.d_other_km,
            b.sum_km,
            b.length_wo_dual_carriageway,
            round(b.done_percent) done_percent,
            b.geom,
            ST_PointOnSurface(b.geom) geom_label,
            (
                SELECT json_agg(ST_AsGeojson(b1.*)::json)
                FROM
                    processing.boundaries_stats b1
                WHERE
                    st_contains(
                        b.geom,
                        ST_PointOnSurface(b1.geom)
                    )
                    AND b1.admin_level > b.admin_level
            ) AS childs
        FROM
            processing.boundaries_stats b
        	  JOIN meta.spatialfilter s ON ST_Intersects(b.geom, s.geom)
    	  WHERE
            s.name = region
        ORDER BY b.admin_level, b.name
    )
SELECT json_build_object(
        'type', 'FeatureCollection',
        'license', 'ODbL 1.0, https://opendatacommons.org/licenses/odbl/',
        'attribution', 'OpenStreetMap, https://www.openstreetmap.org/copyright',
        'bbox', ST_Extent(features.geom),
        'center', ST_Centroid(ST_Extent(features.geom)),
        'timestamp_export', (SELECT CURRENT_TIMESTAMP(0)),
	      'timestamp_osm', (SELECT value FROM o2pmiddle.osm2pgsql_properties WHERE property = 'replication_timestamp'),
        'features', json_agg(st_asgeojson(features.*)::json)
)
FROM features;
$function$;
