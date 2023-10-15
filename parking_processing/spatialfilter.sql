--TODO refactor hardcoded schema, table names and projection
-- intersect with a slightly smaller geometry (-50 m buffer)
DO $$
DECLARE
    rec record;
    spatial_filter GEOMETRY;
BEGIN
    -- Vorab-Berechnung des Spatial Filters einmalig, anstatt für jede Tabelle neu
    SELECT ST_Union(ST_Transform(ST_Buffer(ST_Transform(geom, 25833), -50), 4326))
    INTO spatial_filter
    FROM meta.spatialfilter;

    FOR rec IN
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'import'
    LOOP
        RAISE NOTICE 'Spatial filtering on table: %.%', rec.table_schema, rec.table_name;

        EXECUTE format('DELETE FROM %I.%I AS a WHERE NOT ST_Intersects(a.geom, $1);',
                       rec.table_schema, rec.table_name) USING spatial_filter;
    END LOOP;
END;
$$;


