--TODO refactor hardcoded schema, table names and projection
-- intersect with a slightly smaller geometry (-50 m buffer)
DO
$$
DECLARE
    rec record;
BEGIN
    FOR rec IN
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'import'
    LOOP
        RAISE NOTICE 'spatial filtering on table: %.%', rec.table_schema, rec.table_name;
        EXECUTE format('WITH sf AS (SELECT ST_UNION(ST_Transform(ST_Buffer(ST_Transform(geom, 25833), -50), 4326)) AS geom FROM meta.spatialfilter)
                        DELETE FROM %I.%I AS a
                        USING sf AS s WHERE NOT ST_INTERSECTS(a.geom, s.geom);',
            rec.table_schema, rec.table_name);
    END LOOP;
END;
$$
