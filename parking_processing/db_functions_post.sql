--TODO check hardcoded schema names and apply it only after tables exist
CREATE OR REPLACE FUNCTION public.export_parking_geojson(region text)
 RETURNS json
 LANGUAGE sql
AS $function$
    WITH features AS (
        SELECT
            b.id,
            b.name name,
            b.admin_level,
            b.length_done_km,
            b.length_notdone_km,
            round(b.done_percent) done_percent,
            b.geom,
            ST_PointOnSurface(b.geom) geom_label,
            (
                SELECT json_agg(st_asgeojson(b1.*)::json)
                FROM
                    processing.boundaries_stats b1
                WHERE
                    st_contains(
                        b.geom,
                        st_pointonsurface(b1.geom)
                    )
                    AND b1.admin_level > b.admin_level
            ) AS childs
        FROM
            processing.boundaries_stats b,
            meta.spatialfilter s
        WHERE
            s.name = region
            AND ST_Intersects(ST_Transform(ST_Buffer(ST_Transform(b.geom, 25833), -50), 4326), s.geom)
        ORDER BY b.admin_level, b.admin_name
    )
	SELECT json_build_object(
        'type', 'FeatureCollection',
        'license', 'ODbL 1.0, https://opendatacommons.org/licenses/odbl/',
        'attribution', 'OpenStreetMap, https://www.openstreetmap.org/copyright',
        'bbox', ST_Extent(features.geom),
        'center', ST_Centroid(ST_Extent(features.geom)),
        'timestamp_export', (SELECT CURRENT_TIMESTAMP(0)),
	      'timestamp_osm', (SELECT importdate FROM o2pmiddle.planet_osm_replication_status),
        'features', json_agg(st_asgeojson(features.*)::json)
	)
	FROM features;
$function$;
