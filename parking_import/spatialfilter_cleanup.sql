-- create temporary table, union all geometries
-- convert multi- to single-geometries with st_dump
-- only keep areas with > 5 km²
CREATE TEMP TABLE spf AS
WITH af AS (
    SELECT
        row_number() over() fid,
        name,
        ST_Area((((ST_Dump(ST_Union(geom))).geom)::geography)) / 5000000 as area,
        (ST_Dump(ST_Union(geom))).geom as geom
    FROM meta.spatialfilter
    GROUP BY name
)
SELECT
	name,
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
        ST_Multi(geom)::geometry(MultiPolygon, 4326) geom
    FROM spf
;
ALTER TABLE meta.spatialfilter ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON meta.spatialfilter (id);
DROP TABLE IF EXISTS spf;
