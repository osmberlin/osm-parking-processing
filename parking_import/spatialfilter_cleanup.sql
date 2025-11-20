-- create temporary table, union all geometries
-- convert multi- to single-geometries with st_dump
-- only keep areas with > 5 km²
-- Fix invalid geometries before ST_Union to avoid TopologyException
CREATE TEMP TABLE spf AS
WITH cleaned_geoms AS (
    SELECT
        name,
        label,
        -- Repair invalid geometries: try ST_MakeValid first, fallback to ST_Buffer(geom, 0)
        CASE
            WHEN ST_IsValid(geom) THEN geom
            WHEN ST_IsValid(ST_MakeValid(geom)) THEN ST_MakeValid(geom)
            ELSE ST_Buffer(geom::geography, 0)::geometry
        END AS geom
    FROM meta.spatialfilter
    WHERE geom IS NOT NULL
),
af AS (
    SELECT
        row_number() OVER() AS fid,
        name,
        label,
        -- Use ST_Union with valid geometries (already cleaned in previous CTE)
        -- ST_Union aggregates all geometries in the group
        ST_Area((((ST_Dump(ST_Union(geom))).geom)::geography)) / 5000000 AS area,
        (ST_Dump(ST_Union(geom))).geom as geom
    FROM cleaned_geoms
    GROUP BY name, label
)

SELECT
	name,
	label,
	geom
FROM af
WHERE af.area > 1
;

-- drop current table
-- and rebuild it with content from temp table spf
DROP TABLE IF EXISTS meta.spatialfilter;

-- Rebuild table from temp table spf
-- Use exception handling in case temp table doesn't exist or has no data
DO $$
BEGIN
    CREATE TABLE meta.spatialfilter AS
        SELECT
            name,
            label,
            ST_Multi(geom)::geometry(MultiPolygon, 4326) geom
        FROM spf
    ;
EXCEPTION
    WHEN undefined_table THEN
        -- Create empty table if temp table doesn't exist (e.g., due to errors)
        CREATE TABLE meta.spatialfilter (
            name text,
            label text,
            geom geometry(MultiPolygon, 4326)
        );
        RAISE NOTICE 'Temporary table spf does not exist, created empty spatialfilter table';
    WHEN OTHERS THEN
        -- Create empty table for any other error
        CREATE TABLE meta.spatialfilter (
            name text,
            label text,
            geom geometry(MultiPolygon, 4326)
        );
        RAISE NOTICE 'Error creating spatialfilter from spf: %, created empty table', SQLERRM;
END $$;
ALTER TABLE meta.spatialfilter ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON meta.spatialfilter (id);
CREATE INDEX IF NOT EXISTS spatialfilter_geom_idx ON meta.spatialfilter USING gist (geom);
CREATE INDEX IF NOT EXISTS spatialfilter_name_idx ON meta.spatialfilter(name);
DROP TABLE IF EXISTS spf;
