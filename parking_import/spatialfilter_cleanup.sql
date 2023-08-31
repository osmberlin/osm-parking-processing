-- create temporary table, union all geometries
-- convert multi- to single-geometries with st_dump
-- only keep areas with > 5 km²
CREATE TEMP TABLE spf AS
WITH af AS (
    SELECT
        row_number() OVER() AS fid,
        name,
        label,
        ST_Area((((ST_Dump(ST_Union(geom))).geom)::geography)) / 5000000 AS area,
        (ST_Dump(ST_Union(geom))).geom as geom
    FROM meta.spatialfilter
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
CREATE TABLE meta.spatialfilter AS
    SELECT
        name,
        label,
        ST_Multi(geom)::geometry(MultiPolygon, 4326) geom
    FROM spf
;
ALTER TABLE meta.spatialfilter ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON meta.spatialfilter (id);
CREATE INDEX spatialfilter_geom_idx ON meta.spatialfilter USING gist (geom);
DROP TABLE IF EXISTS spf;
