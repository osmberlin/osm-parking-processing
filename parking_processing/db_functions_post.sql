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
        ORDER BY b.admin_level, b.name
    )
	SELECT json_build_object(
        'type', 'FeatureCollection',
        'license', 'ODbL 1.0, https://opendatacommons.org/licenses/odbl/',
        'attribution', 'OpenStreetMap, https://www.openstreetmap.org/copyright',
        'features', json_agg(st_asgeojson(features.*)::json)
	)
	FROM features;
$function$;
