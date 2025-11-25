SET SEARCH_PATH TO processing, public;

DROP TABLE IF EXISTS amenity_parking_points;
DROP TABLE IF EXISTS boundaries;
DROP TABLE IF EXISTS buffer_area_highway;
DROP TABLE IF EXISTS obstacle_poly;
DROP TABLE IF EXISTS crossings;
DROP TABLE IF EXISTS footways;
DROP TABLE IF EXISTS highways;
DROP TABLE IF EXISTS obstacle_point;
DROP TABLE IF EXISTS obstacle_way;
DROP TABLE IF EXISTS parking_poly;
DROP TABLE IF EXISTS pt_platform;
DROP TABLE IF EXISTS pt_stops;
DROP TABLE IF EXISTS ramps;
DROP TABLE IF EXISTS service;
DROP TABLE IF EXISTS traffic_calming_points;

CREATE TABLE amenity_parking_points AS SELECT * FROM import.amenity_parking_points;
CREATE UNIQUE INDEX ON amenity_parking_points (id);

CREATE TABLE boundaries AS SELECT * FROM import.boundaries;
CREATE UNIQUE INDEX ON boundaries (id);

CREATE TABLE buffer_area_highway AS SELECT * FROM import.area_highway;
CREATE UNIQUE INDEX ON buffer_area_highway (id);

CREATE TABLE obstacle_poly AS SELECT * FROM import.obstacle_poly;
CREATE UNIQUE INDEX ON obstacle_poly (id);

CREATE TABLE crossings AS SELECT * FROM import.crossings;
CREATE UNIQUE INDEX ON crossings (id);

CREATE TABLE footways AS SELECT * FROM import.footways;
CREATE UNIQUE INDEX ON footways (id);

-- Transformiere footways zu local SRS für Berechnungen
ALTER TABLE footways ADD COLUMN IF NOT EXISTS geog geography(LineString, 4326);
UPDATE footways SET geog = geom::geography;
ALTER TABLE footways ALTER COLUMN geom TYPE geometry(LineString, 25833) USING ST_Transform(geom, 25833);
DROP INDEX IF EXISTS footways_geom_idx;
CREATE INDEX footways_geom_idx ON footways USING gist (geom);
DROP INDEX IF EXISTS footways_geog_idx;
CREATE INDEX footways_geog_idx ON footways USING gist (geog);

CREATE TABLE highways AS SELECT * FROM import.highways;
ALTER TABLE highways DROP COLUMN id;
ALTER TABLE highways ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON highways (id);

CREATE TABLE obstacle_point AS SELECT * FROM import.obstacle_point;
CREATE UNIQUE INDEX ON obstacle_point (id);
CREATE INDEX IF NOT EXISTS obstacle_point_geog_idx ON obstacle_point USING gist ((geom::geography));
CREATE INDEX IF NOT EXISTS obstacle_point_geog_idx ON processing.obstacle_point USING gist ((geom::geography));

CREATE TABLE obstacle_way AS SELECT * FROM import.obstacle_way;
CREATE UNIQUE INDEX ON obstacle_way (id);

CREATE TABLE parking_poly AS SELECT * FROM import.parking_poly;
CREATE UNIQUE INDEX ON parking_poly (id);

CREATE TABLE pt_platform AS SELECT * FROM import.pt_platform;
CREATE TABLE pt_stops AS SELECT * FROM import.pt_stops;
CREATE UNIQUE INDEX ON pt_stops (id);

CREATE TABLE ramps AS SELECT * FROM import.ramps;
CREATE UNIQUE INDEX ON ramps (id);

CREATE TABLE service AS SELECT * FROM import.service;
CREATE UNIQUE INDEX ON service (id);

CREATE TABLE traffic_calming_points AS SELECT * FROM import.traffic_calming_points;
CREATE UNIQUE INDEX ON traffic_calming_points (id);


-- insert highway=service into highways table when there are parking information
-- NOTE: id is not included in INSERT list because it's a SERIAL PRIMARY KEY and will be auto-generated
-- Including the id from service would cause PRIMARY KEY constraint violations
INSERT INTO highways
  (osm_type, osm_id, type, geom, surface, name, oneway, operator_type, parking_left_orientation, parking_left_offset, parking_left_position, parking_left_width, parking_left_width_carriageway, parking_right_orientation, parking_right_offset, parking_right_position, parking_right_width, parking_right_width_carriageway, parking_width_proc, parking_width_proc_effective, motorcar, private, disabled)
SELECT
  osm_type, osm_id, type, geom, surface, name, oneway, operator_type, parking_left_orientation, parking_left_offset, parking_left_position, parking_left_width, parking_left_width_carriageway, parking_right_orientation, parking_right_offset, parking_right_position, parking_right_width, parking_right_width_carriageway, parking_width_proc, parking_width_proc_effective, motorcar, private, disabled
FROM
  service
WHERE
  (parking_left_position IN ('lane', 'street_side') OR parking_right_position IN ('lane', 'street_side'))
  AND service IS DISTINCT FROM 'parking_aisle'
  AND (
    parking_left_orientation IN ('diagonal', 'marked', 'parallel', 'perpendicular', 'separate', 'yes')
    OR parking_right_orientation IN ('diagonal', 'marked', 'parallel', 'perpendicular', 'separate', 'yes')
    OR (parking_left_position IN ('lane', 'street_side') AND parking_left_orientation IS NULL)
    OR (parking_right_position IN ('lane', 'street_side') AND parking_right_orientation IS NULL)
  )
;


--transform to local SRS , we can use meters instead of degree for calculations
--TODO check if all ST_* functions used are fine with geography type -> change to geography type
ALTER TABLE highways ADD COLUMN IF NOT EXISTS geog geography(LineString, 4326);
UPDATE highways SET geog = geom::geography;
ALTER TABLE highways ALTER COLUMN geom TYPE geometry(LineString, 25833) USING ST_Transform(geom, 25833);
--ALTER TABLE highways ADD COLUMN IF NOT EXISTS angle numeric;
--UPDATE highways SET angle = degrees(ST_Azimuth(ST_StartPoint(ST_Transform(geom, 25833)), ST_EndPoint(ST_Transform(geom, 25833))));
DROP INDEX IF EXISTS highways_geom_idx;
CREATE INDEX highways_geom_idx ON highways USING gist (geom);
DROP INDEX IF EXISTS highways_geog_idx;
CREATE INDEX highways_geog_idx ON highways USING gist (geog);
CREATE INDEX ON highways (osm_id);


ALTER TABLE highways ADD COLUMN IF NOT EXISTS geog_buffer geography;
UPDATE highways SET geog_buffer = ST_Buffer(geog, ((parking_width_proc_effective / 2) - 0.5), 'endcap=flat');
ALTER TABLE highways ADD COLUMN IF NOT EXISTS geog_buffer_left geography;
UPDATE highways SET geog_buffer_left = ST_Buffer(geog, ((parking_width_proc / 2) + 2), 'side=left endcap=flat');
ALTER TABLE highways ADD COLUMN IF NOT EXISTS geog_buffer_right geography;
UPDATE highways SET geog_buffer_right = ST_Buffer(geog, ((parking_width_proc / 2) + 2), 'side=right endcap=flat');

DROP INDEX IF EXISTS highways_geog_buffer_idx;
CREATE INDEX highways_geog_buffer_idx ON highways USING gist (geog_buffer);
DROP INDEX IF EXISTS highways_geog_buffer_left_idx;
CREATE INDEX highways_geog_buffer_left_idx ON highways USING gist (geog_buffer_left);
DROP INDEX IF EXISTS highways_geog_buffer_right_idx;
CREATE INDEX highways_geog_buffer_right_idx ON highways USING gist (geog_buffer_right);

-- ALTER TABLE trees ADD COLUMN IF NOT EXISTS geog geography(Point, 4326);
-- UPDATE trees SET geog = geom::geography;
-- ALTER TABLE trees ADD COLUMN IF NOT EXISTS geog_buffer geography;
-- UPDATE trees SET geog_buffer = ST_Buffer(geog, 1);
-- DROP INDEX IF EXISTS trees_geog_buffer_idx;
-- CREATE INDEX trees_geog_buffer_idx ON trees USING gist (geog_buffer);

UPDATE boundaries SET geom = ST_Multi(ST_CurveToLine(geom));
ALTER TABLE boundaries ADD COLUMN IF NOT EXISTS geog geography(MultiPolygon, 4326);
UPDATE boundaries SET geog =geom::geography;
ALTER TABLE boundaries ALTER COLUMN geom TYPE geometry(MultiPolygon, 25833) USING ST_Multi(ST_Transform(geom, 25833));
DROP INDEX IF EXISTS boundaries_geom_idx;
CREATE INDEX boundaries_geom_idx ON boundaries USING gist (geom);
DROP INDEX IF EXISTS boundaries_geog_idx;
CREATE INDEX boundaries_geog_idx ON boundaries USING gist (geog);
CREATE INDEX ON boundaries (name);
CREATE INDEX ON boundaries (admin_level);

ALTER TABLE parking_poly ADD COLUMN IF NOT EXISTS geog geography;
UPDATE parking_poly SET geog = geom::geography;
DROP INDEX IF EXISTS parking_poly_geog_idx;
CREATE INDEX parking_poly_geog_idx ON parking_poly USING gist (geog);

-- Ergänze parking_poly um geschätzte Kapazität (Issue #72)
-- capacity_source: 'tag' wenn capacity aus OSM kommt, 'estimated' wenn geschätzt
ALTER TABLE parking_poly ADD COLUMN IF NOT EXISTS capacity_source text;
UPDATE parking_poly SET 
  capacity_source = CASE
    WHEN capacity IS NULL THEN 'estimated'
    ELSE 'tag'
  END,
  capacity = CASE
    WHEN capacity IS NULL THEN GREATEST(1, floor(ST_Area(geog) / 12.2))
    ELSE capacity
  END;

-- Issue #86: Attribut für Art des Parkplatzes (öffentlich/kunden/anwohner)
ALTER TABLE parking_poly ADD COLUMN IF NOT EXISTS parking_access_type text;
UPDATE parking_poly SET parking_access_type = CASE
    -- Öffentlicher Parkplatz: access=yes ODER motorcar=yes|designated (auch wenn access=no)
    WHEN access = 'yes' OR motorcar IN ('yes', 'designated') THEN 'public'
    -- Anwohnerparkplatz: access=private + private=residents
    WHEN access = 'private' AND private = 'residents' THEN 'residents'
    -- Kundenparkplatz: access=customers
    WHEN access = 'customers' THEN 'customers'
    -- Mitarbeiterparkplatz: access=private + private=employees
    WHEN access = 'private' AND private = 'employees' THEN 'employees'
    -- Gewerbeparkplatz: access=private + private=commercial
    WHEN access = 'private' AND private = 'commercial' THEN 'commercial'
    -- Sonstiger/Unbestimmter Parkplatz: alles andere
    ELSE 'other'
END;

ALTER TABLE buffer_area_highway ADD COLUMN IF NOT EXISTS geog geography(Polygon, 4326);
UPDATE buffer_area_highway SET geog = geom::geography;
UPDATE buffer_area_highway SET geog = ST_Buffer(geog, 0.5, 'join=bevel');
DROP INDEX IF EXISTS buffer_area_highway_geog_idx;
CREATE INDEX buffer_area_highway_geog_idx ON buffer_area_highway USING gist (geog);

DROP TABLE IF EXISTS parking_poly_label;
CREATE TABLE parking_poly_label AS
    SELECT
        osm_type,
        osm_id,
        id,
        amenity,
        access,
        capacity,
        capacity_source,
        parking,
        building,
        operator_type,
        parking_orientation,
        parking_access_type,
        area,
        (ST_PointOnSurface(geom))::geometry(Point,4326) geom
    FROM
        parking_poly
;
CREATE UNIQUE INDEX ON parking_poly_label (id);
DROP INDEX IF EXISTS parking_poly_label_geom_idx;
CREATE INDEX parking_poly_label_geom_idx ON parking_poly_label USING gist (geom);

ALTER TABLE service ADD COLUMN IF NOT EXISTS geog geography(LineString, 4326);
UPDATE service SET geog = ST_Transform(geom, 4326)::geography;
ALTER TABLE service ALTER COLUMN geom TYPE geometry(LineString, 25833) USING ST_Transform(geom, 25833);
--ALTER TABLE service ADD COLUMN IF NOT EXISTS angle numeric;
--UPDATE service SET angle = degrees(ST_Azimuth(ST_StartPoint(ST_Transform(geom, 25833)), ST_EndPoint(ST_Transform(geom, 25833))));
DROP INDEX IF EXISTS service_geom_idx;
CREATE INDEX service_geom_idx ON service USING gist (geom);
DROP INDEX IF EXISTS service_geog_idx;
CREATE INDEX service_geog_idx ON service USING gist (geog);


ALTER TABLE crossings ADD COLUMN IF NOT EXISTS geog geography(Point, 4326);
UPDATE crossings SET geog = geom::geography;
ALTER TABLE crossings ALTER COLUMN geom TYPE geometry(Point, 25833) USING ST_Transform(geom, 25833);
ALTER TABLE crossings ADD COLUMN IF NOT EXISTS geog_buffer geography;
UPDATE crossings SET geog_buffer = ST_Buffer(geog, 3);
DROP INDEX IF EXISTS crossings_geog_buffer_idx;
CREATE INDEX crossings_geog_buffer_idx ON crossings USING gist (geog_buffer);
DROP INDEX IF EXISTS crossings_geom_idx;
CREATE INDEX crossings_geom_idx ON crossings USING gist (geom);
DROP INDEX IF EXISTS crossings_geog_idx;
CREATE INDEX crossings_geog_idx ON crossings USING gist (geog);

ALTER TABLE pt_stops ADD COLUMN IF NOT EXISTS geog geography(Point, 4326);
UPDATE pt_stops SET geog = geom::geography;
ALTER TABLE pt_stops ALTER COLUMN geom TYPE geometry(Point, 25833) USING ST_Transform(geom, 25833);
DROP INDEX IF EXISTS pt_stops_geom_idx;
CREATE INDEX pt_stops_geom_idx ON pt_stops USING gist (geom);
DROP INDEX IF EXISTS pt_stops_geog_idx;
CREATE INDEX pt_stops_geog_idx ON pt_stops USING gist (geog);

ALTER TABLE ramps ADD COLUMN IF NOT EXISTS geog geography(Point, 4326);
UPDATE ramps SET geog = geom::geography;
ALTER TABLE ramps ALTER COLUMN geom TYPE geometry(Point, 25833) USING ST_Transform(geom, 25833);
DROP INDEX IF EXISTS ramps_geom_idx;
CREATE INDEX ramps_geom_idx ON ramps USING gist (geom);
DROP INDEX IF EXISTS ramps_geog_idx;
CREATE INDEX ramps_geog_idx ON ramps USING gist (geog);

ALTER TABLE amenity_parking_points ADD COLUMN IF NOT EXISTS geog geography(Point, 4326);
UPDATE amenity_parking_points SET geog = geom::geography;
ALTER TABLE amenity_parking_points ADD COLUMN IF NOT EXISTS geog_buffer geography;
UPDATE amenity_parking_points SET geog_buffer = ST_Buffer(geog, 1);
ALTER TABLE amenity_parking_points ALTER COLUMN geom TYPE geometry(Point, 25833) USING ST_Transform(geom, 25833);
DROP INDEX IF EXISTS amenity_parking_points_geog_buffer_idx;
CREATE INDEX amenity_parking_points_geog_buffer_idx ON amenity_parking_points USING gist (geog_buffer);
DROP INDEX IF EXISTS amenity_parking_points_geom_idx;
CREATE INDEX amenity_parking_points_geom_idx ON amenity_parking_points USING gist (geom);
DROP INDEX IF EXISTS amenity_parking_points_geog_idx;
CREATE INDEX amenity_parking_points_geog_idx ON amenity_parking_points USING gist (geog);



DROP TABLE IF EXISTS highway_union;
CREATE TABLE highway_union AS
WITH hw_union AS (
  SELECT
    h1.name,
    --h1.type,
    array_agg(DISTINCT h1.osm_id) osm_ids,
    (ST_LineMerge(ST_UNION(h1.geog::geometry))) AS geom
  FROM highways h1, highways h2
  WHERE
    h1.type NOT LIKE '%_link'
    AND ST_Intersects(h1.geog, h2.geog)
    AND h1.id <> h2.id
    AND h1.name IS NOT NULL
  GROUP BY h1.name
)
SELECT
  h.name highway_name,
  h.osm_ids,
  --h.type,
  (ST_Dump(h.geom)).path part,
  (ST_Dump(h.geom)).geom geom,
  ((ST_Dump(h.geom)).geom)::geography geog
FROM
  hw_union h
;
ALTER TABLE highway_union ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON highway_union (id);
ALTER TABLE highway_union ADD COLUMN IF NOT EXISTS geog_buffer geography;
UPDATE highway_union SET geog_buffer = ST_Buffer(geog, 1);
ALTER TABLE highway_union ADD COLUMN IF NOT EXISTS geog_buffer_left geography;
UPDATE highway_union SET geog_buffer_left = ST_Buffer(geog, 8, 'side=left');
ALTER TABLE highway_union ADD COLUMN IF NOT EXISTS geog_buffer_right geography;
UPDATE highway_union SET geog_buffer_right = ST_Buffer(geog, 8, 'side=right');
CREATE INDEX highway_union_geom_idx ON highway_union USING gist (geom);
ALTER TABLE highway_union ADD COLUMN IF NOT EXISTS geom_25833 geometry;
UPDATE highway_union SET geom_25833 = ST_Transform(geom, 25833);
CREATE INDEX highway_union_geom_25833_idx ON highway_union USING gist (geom_25833);
DROP INDEX IF EXISTS highway_union_geog_idx;
CREATE INDEX highway_union_geog_idx ON highway_union USING gist (geog);
DROP INDEX IF EXISTS highway_union_geog_buffer_left_idx;
CREATE INDEX highway_union_geog_buffer_idx ON highway_union USING gist (geog_buffer);
DROP INDEX IF EXISTS highway_union_geog_buffer_idx;
CREATE INDEX highway_union_geog_buffer_left_idx ON highway_union USING gist (geog_buffer_left);
DROP INDEX IF EXISTS highway_union_geog_buffer_right_idx;
CREATE INDEX highway_union_geog_buffer_right_idx ON highway_union USING gist (geog_buffer_right);

DROP TABLE IF EXISTS highway_intersections;
CREATE TABLE highway_intersections AS
SELECT
  DISTINCT
  (ST_Dump(
    (ST_Intersection(h1.geog, h2.geog))::geometry
  )).geom AS geom
FROM
  highway_union h1
  INNER JOIN highway_union h2 ON ST_Intersects(h1.geog, h2.geog)
  AND h1.id <> h2.id
  AND h1.highway_name IS DISTINCT FROM h2.highway_name
WHERE ST_GeometryType(ST_Intersection(h1.geom, h2.geom)) = 'ST_Point'

GROUP BY
  ST_Intersection(h1.geog, h2.geog)
;

ALTER TABLE highway_intersections ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON highway_intersections (id);
DROP INDEX IF EXISTS highway_intersections_geom_idx;
CREATE INDEX highway_intersections_geom_idx ON highway_intersections USING gist (geom);

ALTER TABLE highway_intersections ADD COLUMN IF NOT EXISTS geog_buffer geography;
UPDATE highway_intersections SET geog_buffer = ST_Buffer(geom::geography, 5);
DROP INDEX IF EXISTS highway_intersections_geog_buffer_idx;
CREATE INDEX highway_intersections_geog_buffer_idx ON highway_intersections USING gist (geog_buffer);


DROP TABLE IF EXISTS highway_crossings;
CREATE TABLE highway_crossings AS
SELECT
  count(DISTINCT h1.id) anzahl,
  ST_Intersection(h1.geog, h2.geog) geog
--  ST_Buffer(ST_Intersection(h1.geog, h2.geog), 5) geog_buffer,
--  ST_Buffer(ST_Intersection(h1.geog, h2.geog), 10) geog_buffer10
FROM
  highway_union h1
  JOIN highway_union h2 ON ST_Intersects(h1.geog, h2.geog)
  and h1.id <> h2.id
  and h1.highway_name IS DISTINCT FROM h2.highway_name
GROUP BY
  ST_Intersection(h1.geog, h2.geog)
;
ALTER TABLE highway_crossings ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON highway_crossings (id);
DROP INDEX IF EXISTS highway_crossings_geog_idx;
CREATE INDEX highway_crossings_geog_idx ON highway_crossings USING gist (geog);

ALTER TABLE highway_crossings ADD COLUMN IF NOT EXISTS geog_buffer geography;
UPDATE highway_crossings SET geog_buffer = ST_Buffer(geog, 5);
DROP INDEX IF EXISTS highway_crossings_geog_buffer_idx;
CREATE INDEX highway_crossings_geog_buffer_idx ON highway_crossings USING gist (geog_buffer);

ALTER TABLE highway_crossings ADD COLUMN IF NOT EXISTS geom geometry;
UPDATE highway_crossings SET geom = ST_Transform(geog::geometry, 25833);



DROP TABLE IF EXISTS highway_segments;
CREATE TABLE highway_segments AS
WITH crossing_intersecting_highways AS(
  SELECT
    h.id AS lines_id,
    h.highway_name AS highway_name,
    h.geog AS line_geog,
    (ST_Union(c.geog::geometry))::geography AS blade
  FROM highway_union h, highway_crossings c
  WHERE h.geog && c.geog_buffer
  GROUP BY h.id, h.highway_name, h.geog
)
SELECT
 ch.lines_id,
 ch.highway_name,
 --array_agg(DISTINCT h.osm_id) highway_osm_ids,
 --todo let ST_Splap accept geography
 ((ST_Dump(ST_Splap(ch.line_geog::geometry, ch.blade::geometry, 0.0000000000001))).geom)::geography geog
FROM
 crossing_intersecting_highways ch

WHERE
   ST_GeometryType(blade::geometry) IN ('ST_Point', 'ST_MultiPoint')
--GROUP BY ch.lines_id, ch.highway_name,ch.line_geog ,ch.blade
;
ALTER TABLE highway_segments ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON highway_segments (id);
ALTER TABLE highway_segments ADD COLUMN IF NOT EXISTS geog_buffer_left geography;
UPDATE highway_segments SET geog_buffer_left = ST_Buffer(geog, 8, 'side=left endcap=flat');
ALTER TABLE highway_segments ADD COLUMN IF NOT EXISTS geog_buffer_right geography;
UPDATE highway_segments SET geog_buffer_right = ST_Buffer(geog, 8, 'side=right endcap=flat');
ALTER TABLE highway_segments ADD COLUMN IF NOT EXISTS geog_buffer geography;
UPDATE highway_segments SET geog_buffer = ST_Buffer(geog, 8, 'endcap=flat');

DROP INDEX IF EXISTS highway_segments_geog_buffer_left_idx;
CREATE INDEX highway_segments_geog_buffer_left_idx ON highway_segments USING gist (geog_buffer_left);
DROP INDEX IF EXISTS highway_segments_geog_buffer_right_idx;
CREATE INDEX highway_segments_geog_buffer_right_idx ON highway_segments USING gist (geog_buffer_right);
DROP INDEX IF EXISTS highway_segments_geog_buffer_idx;
CREATE INDEX highway_segments_geog_buffer_idx ON highway_segments USING gist (geog_buffer);
DROP INDEX IF EXISTS highway_segments_geog_idx;
CREATE INDEX highway_segments_geog_idx ON highway_segments USING gist (geog);
ALTER TABLE highway_segments ADD COLUMN IF NOT EXISTS geom geometry;
UPDATE highway_segments SET geom = geog::geometry;

DROP INDEX IF EXISTS highway_segments_geom_idx;
CREATE INDEX highway_segments_geom_idx ON highway_segments USING gist (geom);

ALTER TABLE highway_segments ADD COLUMN IF NOT EXISTS geog_x geography;
UPDATE highway_segments hs SET geog_x =
(WITH intersectionbuffer AS (
  SELECT
    hs.id,
    (ST_Union(hi.geog_buffer::geometry))::geometry geom
  FROM
    highway_intersections hi
  WHERE ST_Intersects(hs.geog, hi.geog_buffer)
  GROUP BY hs.id
 )
 SELECT
   ST_Difference(hs.geom, ib.geom)
 FROM
   intersectionbuffer ib,
   highway_segments hs
 WHERE hs.id = ib.id AND hs.geom && ib.geom
);

DELETE FROM highway_segments WHERE ST_Length(geog_x) < 10;

DROP INDEX IF EXISTS highway_segments_geog_x_idx;
CREATE INDEX highway_segments_geog_x_idx ON highway_segments USING gist (geog_x);

ALTER TABLE highway_segments ADD COLUMN IF NOT EXISTS geom_x geometry;
UPDATE highway_segments SET geom_x = ST_Transform(geog_x::geometry, 25833);
DROP INDEX IF EXISTS highway_segments_geom_x_idx;
CREATE INDEX highway_segments_geom_x_idx ON highway_segments USING gist (geom_x);

ALTER TABLE highway_segments ADD COLUMN highway_osm_ids jsonb;
UPDATE highway_segments hs SET highway_osm_ids = (
  SELECT
     jsonb_agg(DISTINCT h.osm_id)
  FROM
    highways h
  WHERE h.id IS NOT NULL AND ST_Intersects(h.geog, hs.geog_x)
  GROUP BY hs.id
  --LIMIT 1
);
DROP INDEX IF EXISTS highway_segments_highway_osm_ids_idx;
CREATE INDEX highway_segments_highway_osm_ids_idx ON highway_segments USING GIN (highway_osm_ids jsonb_path_ops);


DROP TABLE IF EXISTS pp_points;
CREATE TABLE pp_points AS
SELECT DISTINCT ON (pp.id, ((ST_DumpPoints(pp.geom)).path)[2])
  'right' side,
  pp.id pp_id,
  pp.access "access",
  pp.capacity capacity,
  pp.parking parking_position,
  pp.building building,
  pp.operator_type,
  pp.parking_orientation parking_orientation,
  hs.name highway_name,
  hs.id highway_id,
  ((ST_DumpPoints(ST_SimplifyPolygonHull(pp.geom, 0.1))).geom)::geography <-> hs.geog distance,
  ((ST_DumpPoints(ST_SimplifyPolygonHull(pp.geom, 0.1))).path)[2] path,
  ((ST_DumpPoints(ST_SimplifyPolygonHull(pp.geom, 0.1))).geom)::geometry(Point, 4326) geom,
  ((ST_DumpPoints(ST_SimplifyPolygonHull(pp.geom, 0.1))).geom)::geography geog
FROM
  parking_poly pp,
  highways hs
WHERE
  ST_Intersects(hs.geog_buffer_right, pp.geog)
  AND (pp.parking IN ('lane', 'street_side'))
  AND (pp.access NOT IN ('private') OR pp.access IS NULL)
  AND (pp.amenity IN ('parking'))
UNION ALL
SELECT DISTINCT ON (pp.id, ((ST_DumpPoints(pp.geom)).path)[2])
  'left' side,
  pp.id pp_id,
  pp.access "access",
  pp.capacity capacity,
  pp.parking parking_position,
  pp.building building,
  pp.operator_type,
  pp.parking_orientation parking_orientation,
  hs.name highway_name,
  hs.id highway_id,
  ((ST_DumpPoints(ST_SimplifyPolygonHull(pp.geom, 0.1))).geom)::geography <-> hs.geog distance,
  ((ST_DumpPoints(ST_SimplifyPolygonHull(pp.geom, 0.1))).path)[2] path,
  ((ST_DumpPoints(ST_SimplifyPolygonHull(pp.geom, 0.1))).geom)::geometry(Point, 4326) geom,
  ((ST_DumpPoints(ST_SimplifyPolygonHull(pp.geom, 0.1))).geom)::geography geog
FROM
  parking_poly pp,
  highways hs
WHERE
  ST_Intersects(hs.geog_buffer_left, pp.geog)
  AND (pp.parking IN ('lane', 'street_side'))
  AND (pp.access NOT IN ('private') OR pp.access IS NULL)
  AND (pp.amenity IN ('parking'))
;
ALTER TABLE pp_points ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON pp_points (id);
DROP INDEX IF EXISTS pp_points_geom_idx;
CREATE INDEX pp_points_geom_idx ON pp_points USING gist (geom);
DROP INDEX IF EXISTS pp_points_geog_idx;
CREATE INDEX pp_points_geog_idx ON pp_points USING gist (geog);

--let all points of every parking_poly fall down on highway_segment
--sort them by position along the segment
--so we can ST_MakeLine a new line along the highway_segment
DROP TABLE IF EXISTS pl_separated;
CREATE TABLE pl_separated AS
SELECT
  array_agg(DISTINCT h.id) h_id,
  p.side,
  p.pp_id,
  ARRAY_AGG(DISTINCT h.name) highway_name,
  (MIN(p.distance) * -1) min_distance,
  (MAX(p.distance) * -1) max_distance,
  ST_Transform(
    ST_MakeLine(
      ST_ClosestPoint(
        h.geom,
        ST_Transform(p.geom, 25833)
      ) ORDER BY
        ST_LineLocatePoint(
          h.geom,
          ST_ClosestPoint(h.geom, ST_Transform(p.geom, 25833))
        )
    ),
    4326
  )::geometry(Linestring, 4326) geom
FROM
  pp_points p
  JOIN LATERAL (
    SELECT
      h.*
    FROM
      highways h
    WHERE
      h.geog_buffer_right && p.geog
    ORDER BY
      --order by biggest intersection area
      ST_Area(ST_Intersection(h.geog_buffer_right, p.geog)) DESC,
      --afterwards by smallest distance
      p.geog <-> h.geog
    LIMIT 1
  ) AS h ON true
WHERE
  p.side = 'right'
  AND p.highway_name = h.name
GROUP BY
  p.pp_id,
  p.side
UNION ALL
SELECT
  array_agg(DISTINCT h.id) h_id,
  p.side,
  p.pp_id,
  ARRAY_AGG(DISTINCT h.name) highway_name,
  MIN(p.distance) min_distance,
  MAX(p.distance) max_distance,
  ST_Transform(
    ST_MakeLine(
      ST_ClosestPoint(
        h.geom,
        ST_Transform(p.geom, 25833)
      ) ORDER BY
        ST_LineLocatePoint(
          h.geom,
          ST_ClosestPoint(h.geom, ST_Transform(p.geom, 25833))
        )
    ),
    4326
  )::geometry(Linestring, 4326) geom
FROM
  pp_points p
  JOIN LATERAL (
    SELECT
      h.*
    FROM
      highways h
    WHERE
      h.geog_buffer_left && p.geog
    ORDER BY
      --order by biggest intersection area
      ST_Area(ST_Intersection(h.geog_buffer_left, p.geog)) DESC,
      --afterwards by smallest distance
      p.geog <-> h.geog
    LIMIT 1
  ) AS h ON true
WHERE
  p.side = 'left'
  AND p.highway_name = h.name
GROUP BY
  p.pp_id,
  p.side
;
ALTER TABLE pl_separated ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON pl_separated (id);

-- TODO
UPDATE pl_separated SET geom = ST_RemovePoint(geom, ST_NPoints(geom) -1)  WHERE  ST_NPoints(geom) > 2;

ALTER TABLE pl_separated ADD COLUMN IF NOT EXISTS geog geography(LineString, 4326);
UPDATE pl_separated SET geog = geom::geography;
DROP INDEX IF EXISTS pl_separated_geom_idx;
CREATE INDEX pl_separated_geom_idx ON pl_separated USING gist (geom);
DROP INDEX IF EXISTS pl_separated_geog_idx;
CREATE INDEX pl_separated_geog_idx ON pl_separated USING gist (geog);

DROP TABLE IF EXISTS pl_separated_union;
CREATE TABLE pl_separated_union AS
SELECT
  p.id pl_id,
  p.side,
  MIN(p.min_distance) min_distance,
  (ST_LineMerge(ST_Union(p.geom)))::geography geog
FROM
  pl_separated p
WHERE
  ST_Length(p.geog) > 1.7
GROUP BY
  p.side, p.id
;
ALTER TABLE pl_separated_union ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON pl_separated_union (id);
DROP INDEX IF EXISTS pl_separated_union_geog_idx;
CREATE INDEX pl_separated_union_geog_idx ON pl_separated_union USING gist (geog);


DROP TABLE IF EXISTS pp_dumped;
CREATE TABLE pp_dumped AS
SELECT
  p.osm_id,
  p.osm_type,
  p.parking position,
  p.parking_orientation "orientation",
  p.capacity capacity_osm,
  'OSM' "source:capacity_osm",
  CASE
    WHEN p.capacity IS NULL THEN GREATEST(1, floor(ST_Area(p.geog) / 12.2))
    ELSE p.capacity
  END capacity,
  CASE
    WHEN p.capacity IS NULL THEN 'estimated'
    ELSE 'OSM'
  END "source:capacity",
  h.geom <-> ST_Transform(p.geom, 25833) highway_dist,
  ST_Distance(ST_ClosestPoint(h.geom, ST_LineInterpolatePoint(ST_Transform((ST_DumpSegments(p.geom)).geom, 25833), 0.5)), ST_LineInterpolatePoint(ST_Transform((ST_DumpSegments(p.geom)).geom, 25833), 0.5)) dist_closest_point,
  h.osm_id highway_osm_id,
  h.osm_type highway_osm_type,
  degrees(ST_Azimuth(ST_StartPoint((ST_DumpSegments(p.geom)).geom), ST_EndPoint((ST_DumpSegments(p.geom)).geom))) angle,
  (ST_DumpSegments(p.geom)).path,
  ST_Transform((ST_DumpSegments(p.geom)).geom, 25833) geom

FROM
  parking_poly p
  JOIN LATERAL (
    SELECT
      h.*
    FROM
      highways h
    WHERE
      h.geog_buffer && p.geog
    ORDER BY
      --order by biggest intersection area
      GREATEST(ST_Area(ST_Intersection(h.geog_buffer_right, p.geog)), ST_Area(ST_Intersection(h.geog_buffer_left, p.geog))) DESC,
      --afterwards by smallest distance
      h.geom <-> ST_Transform(p.geom, 25833)
    LIMIT 1
  ) AS h ON true
  --highways h
WHERE
  ST_Geometrytype(p.geom) = 'ST_Polygon'
  AND h.geog_buffer && p.geog
;

ALTER TABLE pp_dumped ADD COLUMN id SERIAL PRIMARY KEY;

DROP INDEX IF EXISTS pp_dumped_geom_idx;
CREATE INDEX pp_dumped_geom_idx ON pp_dumped USING gist (geom);
CREATE INDEX pp_dumped_position_idx ON pp_dumped (position);
CREATE INDEX pp_dumped_osm_id_idx ON pp_dumped (osm_id);


DROP TABLE IF EXISTS kerbs_temp;
CREATE TABLE kerbs_temp AS
SELECT
  a.osm_id,
  a.osm_type,
--  a.id,
  v.side,
  a.type highway,
  a.name "highway:name",
  a.osm_id highway_osm_id,
  a.operator_type,
  a.parking_width_proc "highway:width_proc",
  a.parking_width_proc_effective "highway:width_proc:effective",
  a.surface,
  --a.parking_position,
  CASE WHEN v.side = 'left' THEN a.parking_left_position
       WHEN v.side = 'right' THEN a.parking_right_position
  END "position",
  CASE WHEN v.side = 'left' THEN a.parking_left_orientation
       WHEN v.side = 'right' THEN a.parking_right_orientation
  END "orientation",
  CASE
    WHEN v.side = 'left' AND a.parking_left_capacity IS NOT NULL THEN a.parking_left_capacity
    WHEN v.side = 'right' AND a.parking_right_capacity IS NOT NULL THEN a.parking_right_capacity
    ELSE NULL
  END capacity_osm,
  CASE
    WHEN v.side = 'left' AND a.parking_left_capacity IS NOT NULL THEN a.parking_left_source_capacity
    WHEN v.side = 'right' AND a.parking_right_capacity IS NOT NULL THEN a.parking_right_source_capacity
    ELSE NULL
  END "source:capacity_osm",
  0 capacity,
  'estimated' "source:capacity",
  CASE WHEN v.side = 'left' THEN a.parking_left_width_carriageway
       WHEN v.side = 'right' THEN a.parking_right_width_carriageway
  END width,
  CASE WHEN v.side = 'left' THEN a.parking_left_offset
       WHEN v.side = 'right' THEN a.parking_right_offset
  END "offset",
  0 angle,
  0 deg,
  CASE
    WHEN v.side IN ('left') THEN
      ST_Transform(
        ST_OffsetCurve(
          ST_Transform(a.geog::geometry,25833),
          a.parking_left_offset
        ), 4326
      )::geography
    WHEN v.side IN ('right') THEN
      ST_Transform(
        ST_OffsetCurve(
          ST_Transform(a.geog::geometry,25833),
          a.parking_right_offset
        ), 4326
      )::geography
  END geog,
  CASE
    WHEN v.side IN ('left') THEN
        ST_OffsetCurve(
          ST_Transform(a.geog::geometry,25833),
          a.parking_left_offset
        )
    WHEN v.side IN ('right') THEN
        ST_OffsetCurve(
          ST_Transform(a.geog::geometry,25833),
          a.parking_right_offset
        )
  END geom,
  a.geom geom_highway
FROM
  (VALUES ('left'), ('right')) AS v(side)
  CROSS JOIN
  highways a
;
ALTER TABLE kerbs_temp ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON kerbs_temp (id);
CREATE INDEX ON kerbs_temp (highway_osm_id);
CREATE INDEX ON kerbs_temp (osm_id);
DROP INDEX IF EXISTS kerbs_temp_geog_idx;
CREATE INDEX kerbs_temp_geog_idx ON kerbs_temp USING gist (geog);
DROP INDEX IF EXISTS kerbs_temp_geom_idx;
CREATE INDEX kerbs_temp_geom_idx ON kerbs_temp USING gist (geom);

-- Kombinierte UPDATEs für bessere Performance (Performance-Optimierung)
ALTER TABLE kerbs_temp ADD COLUMN IF NOT EXISTS angle numeric;
ALTER TABLE kerbs_temp ADD COLUMN IF NOT EXISTS deg numeric;
ALTER TABLE kerbs_temp ADD COLUMN IF NOT EXISTS geom_buffer geometry(MultiPolygon, 25833);
ALTER TABLE kerbs_temp ADD COLUMN IF NOT EXISTS geom_left_buffer geometry(MultiPolygon, 25833);
ALTER TABLE kerbs_temp ADD COLUMN IF NOT EXISTS geom_right_buffer geometry(MultiPolygon, 25833);
ALTER TABLE kerbs_temp ADD COLUMN IF NOT EXISTS geom_highway_left_buffer geometry(MultiPolygon, 25833);
ALTER TABLE kerbs_temp ADD COLUMN IF NOT EXISTS geom_highway_right_buffer geometry(MultiPolygon, 25833);

-- Einzelnes UPDATE mit CTE für alle Berechnungen
WITH buffer_calc AS (
  SELECT
    id,
    degrees(ST_Azimuth(ST_StartPoint(geom), ST_EndPoint(geom))) AS angle,
    ST_Azimuth(ST_StartPoint(geom), ST_EndPoint(geom)) AS deg,
    ST_Multi(ST_Buffer(geom, 15, 'endcap=flat')) AS geom_buffer,
    ST_Multi(ST_Buffer(geom, 8, 'side=left endcap=flat')) AS geom_left_buffer,
    ST_Multi(ST_Buffer(geom, 8, 'side=right endcap=flat')) AS geom_right_buffer,
    ST_Multi(ST_Buffer(geom_highway, 10, 'side=left endcap=flat')) AS geom_highway_left_buffer,
    ST_Multi(ST_Buffer(geom_highway, 10, 'side=right endcap=flat')) AS geom_highway_right_buffer
  FROM kerbs_temp
)
UPDATE kerbs_temp k
SET
  angle = bc.angle,
  deg = bc.deg,
  geom_buffer = bc.geom_buffer,
  geom_left_buffer = bc.geom_left_buffer,
  geom_right_buffer = bc.geom_right_buffer,
  geom_highway_left_buffer = bc.geom_highway_left_buffer,
  geom_highway_right_buffer = bc.geom_highway_right_buffer
FROM buffer_calc bc
WHERE k.id = bc.id;

DROP INDEX IF EXISTS kerbs_temp_geom_buffer_idx;
CREATE INDEX kerbs_temp_geom_buffer_idx ON kerbs_temp USING gist (geom_buffer);
DROP INDEX IF EXISTS kerbs_temp_geom_left_buffer_idx;
CREATE INDEX kerbs_temp_geom_left_buffer_idx ON kerbs_temp USING gist (geom_left_buffer);
DROP INDEX IF EXISTS kerbs_temp_geom_right_buffer_idx;
CREATE INDEX kerbs_temp_geom_right_buffer_idx ON kerbs_temp USING gist (geom_right_buffer);
DROP INDEX IF EXISTS kerbs_temp_geom_highway_left_buffer_idx;
CREATE INDEX kerbs_temp_geom_highway_left_buffer_idx ON kerbs_temp USING gist (geom_highway_left_buffer);
DROP INDEX IF EXISTS kerbs_temp_geom_highway_right_buffer_idx;
CREATE INDEX kerbs_temp_geom_highway_right_buffer_idx ON kerbs_temp USING gist (geom_highway_right_buffer);

-- Vorberechneter Buffer für joined Tabelle (Performance-Optimierung)
ALTER TABLE kerbs_temp ADD COLUMN IF NOT EXISTS geom_highway_buffer_15 geometry(MultiPolygon, 25833);
UPDATE kerbs_temp SET geom_highway_buffer_15 = ST_Multi(ST_Buffer(geom_highway, 15, 'endcap=flat'));
DROP INDEX IF EXISTS kerbs_temp_geom_highway_buffer_15_idx;
CREATE INDEX kerbs_temp_geom_highway_buffer_15_idx ON kerbs_temp USING gist (geom_highway_buffer_15);




-- Pre-aggregiere Daten für joined Tabelle (Performance-Optimierung)
DROP TABLE IF EXISTS pp_dumped_stats;
CREATE TEMP TABLE pp_dumped_stats AS
SELECT 
  id,
  percentile_cont(0.8) WITHIN GROUP (ORDER BY highway_dist) AS median_dist_to_highway
FROM pp_dumped
GROUP BY id;

CREATE INDEX pp_dumped_stats_id_idx ON pp_dumped_stats (id);

DROP TABLE IF EXISTS pp_dumped_path_stats;
CREATE TEMP TABLE pp_dumped_path_stats AS
SELECT 
  osm_id,
  MAX((path)[2]) AS max_path_id
FROM pp_dumped
GROUP BY osm_id, osm_type;

CREATE INDEX pp_dumped_path_stats_osm_id_idx ON pp_dumped_path_stats (osm_id);

DROP TABLE IF EXISTS pp_dumped_max_dist;
CREATE TEMP TABLE pp_dumped_max_dist AS
SELECT 
  pp.osm_id,
  pp.highway_osm_id,
  MAX(pp.dist_closest_point) AS max_dist
FROM pp_dumped pp
GROUP BY pp.osm_id, pp.osm_type, pp.highway_osm_id;

CREATE INDEX pp_dumped_max_dist_idx ON pp_dumped_max_dist (osm_id, highway_osm_id);

DROP TABLE IF EXISTS highway_segments_dist_stats;
CREATE TEMP TABLE highway_segments_dist_stats AS
SELECT
  p.id AS pp_dumped_id,
  p.highway_osm_id,
  ST_LineInterpolatePoint(p.geom, 0.5) AS mid_point,
  ST_Union(ST_Closestpoint(h.geom_x, ST_LineInterpolatePoint(p.geom, 0.5))) AS k3_c_point,
  avg(ST_Distance(ST_LineInterpolatePoint(p.geom, 0.5), ST_Closestpoint(h.geom_x, ST_LineInterpolatePoint(p.geom, 0.5)))) AS highway_dist_avg,
  array_agg(ST_Distance(ST_LineInterpolatePoint(p.geom, 0.5), ST_Closestpoint(h.geom_x, ST_LineInterpolatePoint(p.geom, 0.5)))) AS highway_dist_array
FROM pp_dumped p
JOIN highway_segments h ON h.highway_osm_ids @> to_jsonb(p.highway_osm_id)
GROUP BY p.id, p.highway_osm_id, p.geom;

CREATE INDEX highway_segments_dist_stats_idx ON highway_segments_dist_stats (pp_dumped_id);

DROP TABLE IF EXISTS pp_dumped_next_segment;
CREATE TEMP TABLE pp_dumped_next_segment AS
SELECT
  p.id,
  p.osm_id,
  (p.path)[2] AS path_id,
  max_path.max_path_id,
  string_agg(ppd.id::text, ',') AS new_angle_ids,
  (SELECT ST_EndPoint(ppd.geom)
   FROM pp_dumped ppd
   WHERE ppd.osm_id = p.osm_id
     AND (ppd.path)[2] = ((p.path)[2]) % max_path.max_path_id + 1
   LIMIT 1) AS new_angle1
FROM pp_dumped p
JOIN pp_dumped_path_stats max_path ON max_path.osm_id = p.osm_id
LEFT JOIN pp_dumped ppd ON ppd.osm_id = p.osm_id 
  AND (ppd.path)[2] = ((p.path)[2]) % max_path.max_path_id + 1
GROUP BY p.id, p.osm_id, (p.path)[2], max_path.max_path_id;

CREATE INDEX pp_dumped_next_segment_id_idx ON pp_dumped_next_segment (id);

DROP TABLE IF EXISTS joined;
  CREATE TABLE joined AS
  SELECT
    p.osm_id pp_osm_id,
    p.osm_type pp_osm_type,
    k.side,
    k.highway,
    k."highway:name",
    k.osm_id highway_osm_id,
    k.osm_type,
    k.operator_type,
    k."highway:width_proc",
    k."highway:width_proc:effective",
    k.surface,
    p.position,
    p."orientation",
    stats.median_dist_to_highway,
    CASE
      WHEN p.capacity IS NULL THEN GREATEST(1, floor(ST_Area(p.geom::geography) / 12.2))
      ELSE p.capacity
    END capacity,
    CASE
      WHEN p.capacity IS NULL THEN 'estimated'
      ELSE 'OSM'
    END "source:capacity",
    0 width,
    k."offset",
    hw_angle.avalue hw_angle,
    k.angle k_angle,
    p.angle p_angle,
    -- winkel zwischen zwei benachbarten Parkflächensegmenten
    next_seg.new_angle_ids new_angle,
    next_seg.new_angle1,
    p.id pp_dumped_id,
    CASE
      WHEN k.side = 'right' THEN acosd(cosd(hw_angle.avalue) * cosd(p.angle) + sind(hw_angle.avalue) * sind(p.angle))
      WHEN k.side = 'left' THEN (180 - acosd(cosd(hw_angle.avalue) * cosd(p.angle) + sind(hw_angle.avalue) * sind(p.angle)))
      ELSE 0
    END k1_value_new_hw,
    acosd(cosd(k.angle) * cosd(p.angle) + sind(k.angle) * sind(p.angle)) k1_value,
    CASE
      WHEN k.side = 'right' THEN acosd(cosd(hw_angle.avalue) * cosd(p.angle) + sind(hw_angle.avalue) * sind(p.angle)) < 30
      WHEN k.side = 'left' THEN (180 - acosd(cosd(hw_angle.avalue) * cosd(p.angle) + sind(hw_angle.avalue) * sind(p.angle))) < 30
      ELSE false
    END k1,
  --  p.highway_osm_id = k.osm_id k2,
    k.osm_id = p.highway_osm_id k2,
    round(p.dist_closest_point::numeric, 2)  k3_p_dist_closest_point,
  round((max_dist.max_dist - p.dist_closest_point)::numeric, 2) < 1.7 k3_new_value,
  round((max_dist.max_dist - p.dist_closest_point)::numeric, 2) k3_new_value_diff,
    p.highway_dist  k3_p_highway_dist,
    round(max_dist.max_dist::numeric, 2) k3_highway_max_dist,
    dist_stats.mid_point k3_li_point,
    dist_stats.k3_c_point,
    (dist_stats.highway_dist_avg > max_dist.max_dist * 0.75) k3_max_dist,
    dist_stats.highway_dist_avg,
    dist_stats.highway_dist_array,
--    (SELECT (ST_Distance(ST_LineInterpolatePoint(p.geom, 0.5), ST_Closestpoint(k.geom, ST_LineInterpolatePoint(p.geom, 0.5))))
--         FROM highway_segments h
--         WHERE h.highway_osm_ids @> to_jsonb(p.highway_osm_id)
--         GROUP BY p.highway_osm_id
--    ) kerb_dist,
    CASE
      WHEN
      k.side = 'right' AND
    -- angle between kerb line and parking segment should be < 26
      acosd(cosd(hw_angle.avalue) * cosd(p.angle) + sind(hw_angle.avalue) * sind(p.angle)) < 30 AND
    -- test if we are on the same street (e.g. not the crossing street)
    -- TODO edge case if parking area opposite a junktion -> more than one highway/kerb segment
      k.osm_id = p.highway_osm_id
    AND
    -- test if distance of parking segment middle point to closest point on highway segment is larger than distance of parking space to highway
         round((max_dist.max_dist - p.dist_closest_point)::numeric, 2) < 1.7
    then true
      WHEN
      k.side = 'left' AND
      (180 - acosd(cosd(hw_angle.avalue) * cosd(p.angle) + sind(hw_angle.avalue) * sind(p.angle))) < 30 AND
       k.osm_id = p.highway_osm_id
      AND
      round((max_dist.max_dist - p.dist_closest_point)::numeric, 2) < 1.7
      then true
      ELSE false
    END keep,
    CASE
      WHEN ST_Intersects(k.geom_highway_left_buffer, p.geom) then true
      WHEN ST_Intersects(k.geom_highway_right_buffer, p.geom) then false
    ELSE false
    END is_left,
    max_path.max_path_id,
    max_dist.max_dist max_dist_closest_point,
    hw_debug.avalue debug_osm_ids,
    k.geom k_geom,
    p.geom p_geom,
    ST_Buffer(k.geom, 15, 'endcap=flat') k_buffer
  FROM
    pp_dumped p
    JOIN pp_dumped_stats stats ON p.id = stats.id
    LEFT JOIN pp_dumped_next_segment next_seg ON p.id = next_seg.id
    LEFT JOIN highway_segments_dist_stats dist_stats ON p.id = dist_stats.pp_dumped_id
    LEFT JOIN pp_dumped_path_stats max_path ON p.osm_id = max_path.osm_id
    LEFT JOIN pp_dumped_max_dist max_dist ON p.osm_id = max_dist.osm_id AND p.highway_osm_id = max_dist.highway_osm_id
    LEFT JOIN LATERAL (
      SELECT
        degrees(
          ST_Azimuth(
            ST_Closestpoint(h.geom_x, ST_LineInterpolatePoint(p.geom, 0.25)),
            ST_Closestpoint(h.geom_x, ST_LineInterpolatePoint(p.geom, 0.75))
          )
        ) avalue
      FROM highway_segments h
    WHERE  h.highway_osm_ids @> to_jsonb(p.highway_osm_id)
    LIMIT 1
    ) AS hw_angle ON true
    CROSS JOIN kerbs_temp k
    LEFT JOIN LATERAL (
      SELECT
        h.highway_osm_ids avalue
      FROM highway_segments h
      WHERE  h.highway_osm_ids @> to_jsonb(p.highway_osm_id)
      --LIMIT 1
    ) AS hw_debug ON true
  WHERE
    k.geom_highway_buffer_15 && p.geom
    AND ST_Intersects(k.geom_highway_buffer_15, p.geom)
    AND k.highway_osm_id = p.highway_osm_id
    AND p.position IN ('street_side', 'lane')
  ;

  ALTER TABLE joined ADD COLUMN id SERIAL PRIMARY KEY;
  CREATE UNIQUE INDEX ON joined (id);
  CREATE INDEX joined_highway_osm_id_idx ON joined (highway_osm_id);

DROP TABLE IF EXISTS joined_lines;
CREATE TABLE joined_lines AS
SELECT
   j.pp_osm_id,
   j.pp_osm_type,
   j.side,
   j.highway,
   j."highway:name",
   j.highway_osm_id,
  j.operator_type,
  j."highway:width_proc",
  j."highway:width_proc:effective",
  j.surface,
  j.position,
  j."orientation",
  NULL capacity_osm,
  NULL "source:capacity_osm",
  j.capacity,
  j."source:capacity",
  j.width,
  (ARRAY_AGG(DISTINCT j.is_left))[0] is_left,
  MAX(j."offset") "offset",
--  MAX(j.highway_dist) highway_dist,
--  MIN(j.kerb_dist) kerb_dist,
  ST_LineMerge(ST_Collect(j.p_geom)) geom
FROM
  joined j
WHERE
  j.keep AND ST_Length(j.p_geom) > 1
GROUP BY
 j.pp_osm_type, j.pp_osm_id, j.side, j.highway, j."highway:name", j.highway_osm_id, j.operator_type, j."highway:width_proc",
 j."highway:width_proc:effective", j.surface, j.position, j."orientation", j.capacity, j."source:capacity", j.width
--  j.osm_type, j.osm_id, j.side
--  j.highway_osm_id, j.side
;
ALTER TABLE joined_lines ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON joined_lines (id);
DROP INDEX IF EXISTS joined_lines_geom_idx;
CREATE INDEX joined_lines_geom_idx ON joined_lines USING gist (geom);

ALTER TABLE joined_lines ADD COLUMN IF NOT EXISTS geom_buffer geometry;
UPDATE joined_lines SET geom_buffer =
CASE
WHEN side = 'left' AND is_left THEN ST_Buffer(geom, ("offset") , 'side=left endcap=flat')
WHEN side = 'left' AND NOT is_left THEN ST_Buffer(geom, ("offset") , 'side=right endcap=flat')
WHEN side = 'right' AND is_left THEN ST_Buffer(geom, ("offset") , 'side=left endcap=flat')
WHEN side = 'right' AND NOT is_left THEN ST_Buffer(geom, ("offset") , 'side=right endcap=flat')
END;

ALTER TABLE joined_lines ADD COLUMN IF NOT EXISTS geog geography;
UPDATE joined_lines SET geog = (ST_Transform(ST_Multi(geom), 4326))::geography(MultiLineString, 4326);
DROP INDEX IF EXISTS joined_lines_geog_idx;
CREATE INDEX joined_lines_geog_idx ON joined_lines USING gist (geog);

ALTER TABLE joined_lines ADD COLUMN IF NOT EXISTS geog_buffer geography;
UPDATE joined_lines SET geog_buffer = (ST_Transform(ST_Multi(geom_buffer), 4326))::geography(MultiPolygon, 4326);
DROP INDEX IF EXISTS joined_lines_geog_buffer_idx;
CREATE INDEX joined_lines_geog_buffer_idx ON joined_lines USING gist (geog_buffer);



DROP TABLE IF EXISTS parking_lanes_temp;
CREATE TABLE parking_lanes_temp AS
SELECT
  a.osm_id,
  a.osm_type,
--  a.id,
  v.side,
  a.type highway,
  a.name "highway:name",
  a.operator_type,
  a.parking_width_proc "highway:width_proc",
  a.parking_width_proc_effective "highway:width_proc:effective",
  a.surface,
  --a.parking_position,
  CASE WHEN v.side = 'left' THEN a.parking_left_position
       WHEN v.side = 'right' THEN a.parking_right_position
  END "position",
  CASE WHEN v.side = 'left' THEN a.parking_left_orientation
       WHEN v.side = 'right' THEN a.parking_right_orientation
  END "orientation",
  CASE
    WHEN v.side = 'left' AND a.parking_left_capacity IS NOT NULL THEN a.parking_left_capacity
    WHEN v.side = 'right' AND a.parking_right_capacity IS NOT NULL THEN a.parking_right_capacity
    ELSE NULL
  END capacity_osm,
  CASE
    WHEN v.side = 'left' AND a.parking_left_capacity IS NOT NULL THEN a.parking_left_source_capacity
    WHEN v.side = 'right' AND a.parking_right_capacity IS NOT NULL THEN a.parking_right_source_capacity
    ELSE NULL
  END "source:capacity_osm",
  0 capacity,
  'estimated' "source:capacity",
  CASE WHEN v.side = 'left' THEN a.parking_left_width_carriageway
       WHEN v.side = 'right' THEN a.parking_right_width_carriageway
  END width,
  CASE WHEN v.side = 'left' THEN a.parking_left_offset
       WHEN v.side = 'right' THEN a.parking_right_offset
  END "offset",
  CASE WHEN v.side = 'left' THEN a.parking_condition_left
       WHEN v.side = 'right' THEN a.parking_condition_right
  END parking_condition,
  CASE WHEN v.side = 'left' THEN a.parking_condition_left_other
       WHEN v.side = 'right' THEN a.parking_condition_right_other
  END parking_condition_other,
  CASE WHEN v.side = 'left' THEN a.parking_condition_left_other_time
       WHEN v.side = 'right' THEN a.parking_condition_right_other_time
  END parking_condition_other_time,
  CASE WHEN v.side = 'left' THEN a.parking_condition_left_default
       WHEN v.side = 'right' THEN a.parking_condition_right_default
  END parking_condition_default,
  CASE WHEN v.side = 'left' THEN a.parking_condition_left_time_interval
       WHEN v.side = 'right' THEN a.parking_condition_right_time_interval
  END parking_condition_time_interval,
  CASE WHEN v.side = 'left' THEN a.parking_condition_left_maxstay
       WHEN v.side = 'right' THEN a.parking_condition_right_maxstay
  END parking_condition_maxstay,
  CASE WHEN v.side = 'left' THEN a.parking_left_fee
       WHEN v.side = 'right' THEN a.parking_right_fee
  END fee,
  CASE WHEN v.side = 'left' THEN a.parking_left_fee_conditional
       WHEN v.side = 'right' THEN a.parking_right_fee_conditional
  END fee_conditional,
  CASE WHEN v.side = 'left' THEN a.parking_left_access
       WHEN v.side = 'right' THEN a.parking_right_access
  END access,
  CASE WHEN v.side = 'left' THEN a.parking_left_restriction
       WHEN v.side = 'right' THEN a.parking_right_restriction
  END restriction,
  CASE WHEN v.side = 'left' THEN a.parking_left_restriction_taxi
       WHEN v.side = 'right' THEN a.parking_right_restriction_taxi
  END restriction_taxi,
  CASE WHEN v.side = 'left' THEN a.parking_left_restriction_disabled
       WHEN v.side = 'right' THEN a.parking_right_restriction_disabled
  END restriction_disabled,
  CASE WHEN v.side = 'left' THEN a.parking_left_restriction_car_sharing
       WHEN v.side = 'right' THEN a.parking_right_restriction_car_sharing
  END restriction_car_sharing,
  CASE WHEN v.side = 'left' THEN a.parking_left_zone
       WHEN v.side = 'right' THEN a.parking_right_zone
  END zone,
  a.motorcar,
  a.private,
  a.disabled,
  CASE
    -- before offsetting we cut out all separated parking lanes
    WHEN v.side IN ('left') THEN
      ST_Transform(
        ST_OffsetCurve(
          ST_Transform(
            ST_Difference(
              ST_SetSRID(a.geog::geometry, 4326),
              ST_SetSRID(COALESCE(ST_Buffer(s.geog, 0.2, 'endcap=flat'), 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
            ),
            25833
          ),
          a.parking_left_offset
        ), 4326
      )::geography
    WHEN v.side IN ('right') THEN
      ST_Transform(
        ST_OffsetCurve(
          ST_Transform(
            ST_Difference(
              ST_SetSRID(a.geog::geometry, 4326),
              ST_SetSRID(COALESCE(ST_Buffer(s.geog, 0.2, 'endcap=flat'), 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
            ),
            25833
          ),
          a.parking_right_offset
        ), 4326
      )::geography
  END geog
  --(a.error_output#>>'{}')::jsonb error_output
FROM
  (VALUES ('left'), ('right')) AS v(side)
  CROSS JOIN
  highways a
  LEFT JOIN pl_separated_union s ON ST_Intersects(s.geog, ST_Buffer(a.geog, 0.2)) AND v.side = s.side
UNION ALL
SELECT
  j.pp_osm_id,
  j.pp_osm_type,
  j.side,
  j.highway,
  j."highway:name",
  j.operator_type,
  j."highway:width_proc",
  j."highway:width_proc:effective",
  j.surface,
  j.position,
  j."orientation",
  NULL capacity_osm,
  NULL "source:capacity_osm",
  j.capacity,
  j."source:capacity",
  0 width,
  j."offset",
  NULL parking_condition,
  NULL parking_condition_other,
  NULL parking_condition_other_time,
  NULL parking_condition_default,
  NULL parking_condition_time_interval,
  NULL parking_condition_maxstay,
  NULL fee,
  NULL fee_conditional,
  NULL access,
  NULL restriction,
  NULL restriction_taxi,
  NULL restriction_disabled,
  NULL restriction_car_sharing,
  NULL zone,
  NULL motorcar,
  NULL private,
  NULL disabled,
  ST_Transform(j.geom, 4326)::geography geog
  --NULL error_output
FROM
  joined_lines j
;
ALTER TABLE parking_lanes_temp ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON parking_lanes_temp (id);
CREATE UNIQUE INDEX parking_lanes_temp_pk_idx ON parking_lanes_temp USING btree (id ASC NULLS LAST);
DROP INDEX IF EXISTS parking_lanes_temp_geog_idx;
CREATE INDEX parking_lanes_temp_geog_idx ON parking_lanes_temp USING gist (geog);
-- DROP INDEX IF EXISTS parking_lanes_temp_geog_shorten_idx;
-- CREATE INDEX parking_lanes_temp_geog_shorten_idx ON parking_lanes_temp USING gist (geog_shorten);

DROP TABLE IF EXISTS parking_lanes;
CREATE TABLE parking_lanes AS
SELECT
  osm_id,
  osm_type,
  side,
  highway,
  "highway:name",
  operator_type,
  "highway:width_proc",
  "highway:width_proc:effective",
  surface,
  "position",
  orientation,
  capacity_osm,
  "source:capacity_osm",
  capacity,
  "source:capacity",
  width,
  "offset",
  parking_condition,
  parking_condition_other,
  parking_condition_other_time,
  parking_condition_default,
  parking_condition_time_interval,
  parking_condition_maxstay,
  fee,
  fee_conditional,
  access,
  restriction,
  restriction_taxi,
  restriction_disabled,
  restriction_car_sharing,
  zone,
  motorcar,
  private,
  disabled,
  --error_output,
  (ST_Multi(ST_Union(geog::geometry)))::geometry(MultiLineString, 4326) geom,
  ST_Union(geog::geometry)::geography geog
FROM
  parking_lanes_temp
GROUP BY
  osm_id,
  osm_type,
  side,
  highway,
  "highway:name",
  operator_type,
  "highway:width_proc",
  "highway:width_proc:effective",
  surface,
  "position",
  orientation,
  capacity_osm,
  "source:capacity_osm",
  capacity,
  "source:capacity",
  width,
  "offset",
  parking_condition,
  parking_condition_other,
  parking_condition_other_time,
  parking_condition_default,
  parking_condition_time_interval,
  parking_condition_maxstay,
  fee,
  fee_conditional,
  access,
  restriction,
  restriction_taxi,
  restriction_disabled,
  restriction_car_sharing,
  zone,
  motorcar,
  private,
  disabled
  --error_output
;
ALTER TABLE parking_lanes ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX parking_lanes_pk_idx ON parking_lanes USING btree (id ASC NULLS LAST);
DROP INDEX IF EXISTS parking_lanes_geom_idx;
CREATE INDEX parking_lanes_geom_idx ON parking_lanes USING gist (geom);
DROP INDEX IF EXISTS parking_lanes_geog_idx;
CREATE INDEX parking_lanes_geog_idx ON parking_lanes USING gist (geog);

DROP TABLE IF EXISTS buffer_obstacle;
CREATE TABLE buffer_obstacle AS
-- Polygone
SELECT
	ST_Multi(poly.geom) geom_buffer
FROM
	obstacle_poly poly
UNION ALL
-- Punkte mit Puffer
SELECT
    ST_Multi(ST_Buffer(point.geom::geography, point.buffer)::geometry) geom_buffer
FROM
  obstacle_point point
UNION ALL
-- Linien mit Puffer
SELECT
    ST_Multi(ST_Buffer(way.geom::geography, way.buffer, 'endcap=flat')::geometry) geom_buffer
FROM
  obstacle_way way
;
ALTER TABLE buffer_obstacle ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON buffer_obstacle (id);
ALTER TABLE buffer_obstacle ALTER COLUMN geom_buffer TYPE geometry(MultiPolygon, 4326);
CREATE INDEX buffer_obstacle_geom_idx ON buffer_obstacle USING gist (geom_buffer);
ALTER TABLE buffer_obstacle ADD COLUMN IF NOT EXISTS geog geography(MultiPolygon, 4326);
UPDATE buffer_obstacle SET geog = geom_buffer::geography;
CREATE INDEX buffer_obstacle_geog_idx ON buffer_obstacle USING gist (geog);

DROP TABLE IF EXISTS pt_bus;
CREATE TABLE pt_bus AS
SELECT
  p.osm_id,
  p.osm_type,
  p.id pt_id,
  p.name,
  'right' side,
  ST_Transform(
    ST_OffsetCurve(
      --get highway intersection with buffered bus_stop
      ST_Intersection(
        ST_Transform((h.geog)::geometry, 25833),
        --buffer bus_stop with 15 m
        ST_Buffer(
          --snap bus_stop on highway
          ST_ClosestPoint(
            ST_Transform(h.geog::geometry, 25833),
            ST_Transform(p.geog::geometry, 25833)
          )
          , 15
        )
      )
      , h.parking_right_offset
    )
    , 4326
  ) geom
FROM
  pt_stops p
  JOIN LATERAL (
    SELECT
      h.*
    FROM
      highways h
    WHERE
      ST_Intersects(h.geog_buffer_right, p.geog)
    ORDER BY
      p.geog <-> h.geog
    LIMIT 1
  ) AS h ON true
WHERE
  p.geog && h.geog_buffer_right
  AND p.highway = 'bus_stop'
UNION ALL
SELECT
  p.osm_id,
  p.osm_type,
  p.id pt_id,
  p.name,
  'left' side,
  ST_Transform(
    ST_OffsetCurve(
      --get highway intersection with buffered bus_stop
      ST_Intersection(
        ST_Transform((h.geog)::geometry, 25833),
        --buffer bus_stop with 15 m
        ST_Buffer(
          --snap bus_stop on highway
          ST_ClosestPoint(
            ST_Transform(h.geog::geometry, 25833),
            ST_Transform(p.geog::geometry, 25833)
          )
          , 15
        )
      )
      , h.parking_left_offset
    )
    , 4326
  ) geom
FROM
  pt_stops p
  JOIN LATERAL (
    SELECT
      h.*
    FROM
      highways h
    WHERE
      ST_Intersects(h.geog_buffer_left, p.geog)
    ORDER BY
      p.geog <-> h.geog
    LIMIT 1
  ) AS h ON true
WHERE
  p.geog && h.geog_buffer_left
  AND p.highway = 'bus_stop'
;
--TODO dont do this
DELETE FROM pt_bus WHERE ST_GeometryType(geom) = 'ST_MultiLineString';
ALTER TABLE pt_bus ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON pt_bus (id);
ALTER TABLE pt_bus ADD COLUMN IF NOT EXISTS geog geography(LineString, 4326);
UPDATE pt_bus SET geog = geom::geography;

DROP INDEX IF EXISTS pt_bus_geom_idx;
CREATE INDEX pt_bus_geom_idx ON pt_bus USING gist (geom);
DROP INDEX IF EXISTS pt_bus_geog_idx;
CREATE INDEX pt_bus_geog_idx ON pt_bus USING gist (geog);


DROP TABLE IF EXISTS buffer_pt_bus;
CREATE TABLE buffer_pt_bus AS
SELECT
  p.id,
  (ST_Union(ST_Buffer(b.geog, 1, 'endcap=flat')::geometry))::geography geog,
  ST_Multi((ST_Union(ST_Buffer(b.geog, 1, 'endcap=flat')::geometry)))::geometry(Multipolygon, 4326) geom_buffer
FROM
  parking_lanes p JOIN pt_bus b ON st_intersects(b.geog, p.geog)
WHERE
  p.position NOT IN ('street_side')
GROUP BY
  p.id
;
CREATE UNIQUE INDEX ON buffer_pt_bus (id);
DROP INDEX IF EXISTS buffer_pt_bus_geog_idx;
CREATE INDEX buffer_pt_bus_geog_idx ON buffer_pt_bus USING gist (geog);
DROP INDEX IF EXISTS buffer_pt_bus_geom_idx;
CREATE INDEX buffer_pt_bus_geom_idx ON buffer_pt_bus USING gist (geom_buffer);


DROP TABLE IF EXISTS pt_tram;
CREATE TABLE pt_tram AS
SELECT
  p.osm_id,
  p.osm_type,
  p.id pt_id,
  p.name,
  'right' side,
  ST_Transform(
    ST_OffsetCurve(
      --get highway intersection with buffered tram_stop
      ST_Intersection(
        ST_Transform((h.geog)::geometry, 25833),
        --buffer tram_stop with 15 m
        ST_Buffer(
          --snap tram_stop on highway
          ST_ClosestPoint(
            ST_Transform(h.geog::geometry, 25833),
            ST_Transform(p.geog::geometry, 25833)
          )
          , 15
        )
      )
      , h.parking_right_offset
    )
    , 4326
  ) geom
FROM
  pt_stops p
  JOIN LATERAL (
    SELECT
      h.*
    FROM
      highways h
    WHERE
      ST_Intersects(h.geog_buffer_right, p.geog)
    ORDER BY
      p.geog <-> h.geog
    LIMIT 1
  ) AS h ON true
WHERE
  p.geog && h.geog_buffer_right
  AND p.railway = 'tram_stop'
UNION ALL
SELECT
  p.osm_id,
  p.osm_type,
  p.id pt_id,
  p.name,
  'left' side,

  ST_Transform(
    ST_OffsetCurve(
      --get highway intersection with buffered tram_stop
      ST_Intersection(
        ST_Transform((h.geog)::geometry, 25833),
        --buffer tram_stop with 15 m
        ST_Buffer(
          --snap tram_stop on highway
          ST_ClosestPoint(
            ST_Transform(h.geog::geometry, 25833),
            ST_Transform(p.geog::geometry, 25833)
          )
          , 15
        )
      )
      , CASE WHEN h.oneway THEN h.parking_right_offset ELSE h.parking_left_offset END
    )
    , 4326
  ) geom
FROM
  pt_stops p
  JOIN LATERAL (
    SELECT
      h.*
    FROM
      highways h
    WHERE
      ST_Intersects(h.geog_buffer_left, p.geog)
    ORDER BY
      p.geog <-> h.geog
    LIMIT 1
  ) AS h ON true
WHERE
  p.geog && h.geog_buffer_left
  AND p.railway = 'tram_stop'
;
--TODO dont do this
DELETE FROM pt_tram WHERE ST_GeometryType(geom) = 'ST_MultiLineString';
ALTER TABLE pt_tram ADD COLUMN id SERIAL PRIMARY KEY;

CREATE UNIQUE INDEX ON pt_tram (id);
ALTER TABLE pt_tram ADD COLUMN IF NOT EXISTS geog geography(LineString, 4326);
UPDATE pt_tram SET geog = geom::geography;

DROP INDEX IF EXISTS pt_tram_geom_idx;
CREATE INDEX pt_tram_geom_idx ON pt_tram USING gist (geom);
DROP INDEX IF EXISTS pt_tram_geog_idx;
CREATE INDEX pt_tram_geog_idx ON pt_tram USING gist (geog);

DROP TABLE IF EXISTS buffer_pt_tram;
CREATE TABLE buffer_pt_tram AS
SELECT
  p.id,
  (ST_Union(ST_Buffer(b.geog, 1, 'endcap=flat')::geometry))::geography geog,
  ST_Multi((ST_Union(ST_Buffer(b.geog, 1, 'endcap=flat')::geometry)))::geometry(Multipolygon, 4326) geom_buffer
FROM
  parking_lanes p JOIN pt_tram b ON st_intersects(b.geog, p.geog)
WHERE
  p.position NOT IN ('street_side')
GROUP BY
  p.id
;
DROP INDEX IF EXISTS buffer_pt_tram_geog_idx;
CREATE INDEX buffer_pt_tram_geog_idx ON buffer_pt_tram USING gist (geog);
DROP INDEX IF EXISTS buffer_pt_tram_geom_idx;
CREATE INDEX buffer_pt_tram_geom_idx ON buffer_pt_tram USING gist (geom_buffer);

DROP TABLE IF EXISTS parking_lanes_single;
CREATE TABLE parking_lanes_single AS
SELECT
    id pl_id,
    osm_id,
    osm_type,
    side,
    highway,
    "highway:name",
    operator_type,
    "highway:width_proc",
    "highway:width_proc:effective",
    surface,
    orientation,
    "position",
    capacity_osm,
    "source:capacity_osm",
    capacity,
    "source:capacity",
    width,
    "offset",
    --error_output,
    (ST_DUMP(pl.geog::geometry)).path,
    ((ST_DUMP(pl.geog::geometry)).geom)::geography geog
FROM
  parking_lanes pl
;
ALTER TABLE parking_lanes_single ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON parking_lanes_single (id);
DROP INDEX IF EXISTS parking_lanes_single_geog_idx;
CREATE INDEX parking_lanes_single_geog_idx ON parking_lanes_single USING gist (geog);


DROP TABLE IF EXISTS ped_crossings;
CREATE TABLE ped_crossings AS
SELECT DISTINCT ON (p.side, c.id)
  c.osm_id crossing_osm_id,
  c.osm_type crossing_osm_type,
  c.id crossing_id,
  p.side,
  h.id highway_id,
  h.osm_id highway_osm_id,
  h.osm_type highways_osm_type,
  c.highway,
  c.crossing,
  c.crossing_ref,
  c.kerb,
  c.crossing_buffer_marking "crossing:buffer_marking",
  c.crossing_kerb_extension "crossing:kerb_extension",
  c.traffic_signals_direction "traffic_signals:direction",
  h.parking_width_proc "width_proc",
  CASE
    WHEN p.side IN ('left') THEN h.parking_left_width_carriageway
    WHEN p.side IN ('right') THEN h.parking_right_width_carriageway
  END "parking:width:carriageway",
  h.parking_left_width_carriageway "parking:left:width:carriageway",
  h.parking_right_width_carriageway "parking:right:width:carriageway",
  c.geom geom,
  CASE
    WHEN p.side IN ('left') THEN ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography
    WHEN p.side IN ('right') THEN ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography
  END geog_offset,
  CASE
    WHEN p.side IN ('left') THEN
      CASE
      WHEN c.highway = 'traffic_signals' AND c.traffic_signals_direction IN ('backward') THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 10)
      WHEN c.highway = 'traffic_signals' AND c.traffic_signals_direction IN ('forward') AND p.offset < 0 THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 10)
      WHEN c.highway = 'traffic_signals' AND c.traffic_signals_direction NOT IN ('forward', 'backward') AND ST_Intersects(ST_Buffer(p.geog, COALESCE(p.offset, 4), 'side=left endcap=flat'), c.geog) THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 10)
      WHEN c.crossing_kerb_extension = 'both' OR c.crossing_buffer_marking = 'both' THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 3)
      WHEN c.crossing_kerb_extension = p.side OR c.crossing_buffer_marking = p.side THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 3)
      WHEN c.crossing = 'zebra' OR c.crossing_ref = 'zebra' OR c.crossing = 'traffic_signals' THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 4.5)
      WHEN c.crossing = 'marked' THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 2)
      WHEN c.highway = 'crossing' AND c.crossing_buffer_marking IS NULL AND c.crossing_kerb_extension IS NULL THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 2.5)
      --ELSE ST_Buffer(c.geog, 1)
    END
    WHEN p.side IN ('right') THEN
      CASE
        WHEN c.highway = 'traffic_signals' AND c.traffic_signals_direction IN ('forward') THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 10)
        WHEN c.highway = 'traffic_signals' AND c.traffic_signals_direction IN ('backward')  AND p.offset > 0 THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 10)
        WHEN c.highway = 'traffic_signals' AND c.traffic_signals_direction NOT IN ('forward', 'backward') AND ST_Intersects(ST_Buffer(p.geog, COALESCE(p.offset, 4), 'side=left endcap=flat'), c.geog) THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 10)
        WHEN c.crossing_kerb_extension = 'both' OR c.crossing_buffer_marking = 'both' THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 3)
        WHEN c.crossing_kerb_extension = p.side OR c.crossing_buffer_marking = p.side THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 3)
        WHEN c.crossing = 'zebra' OR c.crossing_ref = 'zebra' OR c.crossing = 'traffic_signals' THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 4.5)
        WHEN c.crossing = 'marked' THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 2)
        WHEN c.highway = 'crossing' AND c.crossing_buffer_marking IS NULL AND c.crossing_kerb_extension IS NULL THEN ST_Buffer(ST_Transform(ST_ClosestPoint(ST_Transform(p.geog::geometry, 25833), c.geom), 4326)::geography, 2.5)
        --ELSE ST_Buffer(c.geog, 1)
      END
  END geog_offset_buffer,
  CASE
     WHEN p.side IN ('left') THEN
       CASE
        WHEN c.highway = 'traffic_signals' AND c.traffic_signals_direction IN ('backward') THEN 11
        WHEN c.highway = 'traffic_signals' AND c.traffic_signals_direction NOT IN ('forward', 'backward') AND ST_Intersects(ST_Buffer(p.geog, COALESCE(p.offset, 4), 'side=left endcap=flat'), c.geog) THEN 12
        WHEN c.crossing_kerb_extension = 'both' OR c.crossing_buffer_marking = 'both' THEN 13
        WHEN c.crossing_kerb_extension = p.side OR c.crossing_buffer_marking = p.side THEN 14
        WHEN c.crossing = 'zebra' OR c.crossing_ref = 'zebra' OR c.crossing = 'traffic_signals' THEN 15
        WHEN c.crossing = 'marked' THEN 16
        ELSE 17
      END
     WHEN p.side IN ('right') THEN
      CASE
        WHEN c.highway = 'traffic_signals' AND c.traffic_signals_direction IN ('forward') THEN 21
        WHEN c.highway = 'traffic_signals' AND c.traffic_signals_direction NOT IN ('forward', 'backward') AND ST_Intersects(ST_Buffer(p.geog, COALESCE(p.offset, 4), 'side=left endcap=flat'), c.geog) THEN 22
        WHEN c.crossing_kerb_extension = 'both' OR c.crossing_buffer_marking = 'both' THEN 23
        WHEN c.crossing_kerb_extension = p.side OR c.crossing_buffer_marking = p.side THEN 24
        WHEN c.crossing = 'zebra' OR c.crossing_ref = 'zebra' OR c.crossing = 'traffic_signals' THEN 25
        WHEN c.crossing = 'marked' THEN 26
        ELSE 27
      END
  END num_geog,
  c.geog geom_crossing
FROM
  crossings c
  JOIN highways h ON ST_Intersects(c.geog_buffer, h.geog)
  JOIN parking_lanes_single p ON ST_Intersects(c.geog_buffer, ST_Buffer(p.geog, ABS(p.offset)) )
WHERE
  (c.crossing_buffer_marking IS NOT NULL
  OR c.crossing_kerb_extension IS NOT NULL
  OR c.highway IN ('traffic_signals', 'crossing') )
ORDER BY
  p.side, c.id, ST_Distance(c.geog, p.geog)
;
ALTER TABLE ped_crossings ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON ped_crossings (id);
DROP INDEX IF EXISTS ped_crossings_geog_offset_buffer_idx;
CREATE INDEX ped_crossings_geog_offset_buffer_idx ON ped_crossings USING gist (geog_offset_buffer);


DROP TABLE IF EXISTS ssr;
CREATE TABLE ssr AS
SELECT
  s.type,
  s.surface,
  s.name,
--  s.parking_position,
  s.parking_left_orientation,
  s.parking_right_orientation,
  s.parking_width_proc,
  s.parking_width_proc_effective,
  s.parking_left_position,
  s.parking_right_position,
  s.parking_left_width,
  s.parking_right_width,
  s.parking_left_width_carriageway,
  s.parking_right_width_carriageway,
  s.parking_left_offset,
  s.parking_right_offset,
  --(s.error_output#>>'{}')::jsonb error_output,
  ST_Buffer(ST_Intersection(s.geog, h.geog), (h.parking_width_proc / 2) + 5) geog
FROM service s
  JOIN highways h ON ST_Intersects(s.geog, h.geog)
WHERE
 s.parking_left_orientation IS NOT NULL
 OR s.parking_right_orientation IS NOT NULL
;
ALTER TABLE ssr ADD COLUMN id SERIAL PRIMARY KEY;
DROP INDEX IF EXISTS ssr_geog_idx;
CREATE INDEX ssr_geog_idx ON ssr USING gist (geog);

DROP TABLE IF EXISTS driveways;
CREATE TABLE driveways AS
SELECT
  s.type,
  s.osm_id,
  s.osm_type,
  s.surface,
  s.name,
  s.parking_left_position,
  s.parking_right_position,
  s.parking_left_orientation,
  s.parking_right_orientation,
  s.parking_width_proc,
  s.parking_width_proc_effective,
  s.parking_left_width,
  s.parking_right_width,
  s.parking_left_width_carriageway,
  s.parking_right_width_carriageway,
  s.parking_left_offset,
  s.parking_right_offset,
  --(s.error_output#>>'{}')::jsonb error_output,
  ST_Buffer(ST_Intersection(s.geog, p.geog), GREATEST((s.parking_width_proc / 2), 2) ) geog
FROM service s
  JOIN parking_lanes p ON ST_Intersects(s.geog, p.geog)
WHERE
  s.geog && p.geog
  AND s.type IN ('service')
;
ALTER TABLE driveways ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON driveways (id);
DROP INDEX IF EXISTS driveways_geog_idx;
CREATE INDEX driveways_geog_idx ON driveways USING gist (geog);
ALTER TABLE driveways ADD COLUMN IF NOT EXISTS geom geometry(MultiPolygon, 25833);
UPDATE driveways SET geom = ST_Multi(ST_Transform(geog::geometry, 25833));
DROP INDEX IF EXISTS driveways_geom_idx;
CREATE INDEX driveways_geom_idx ON driveways USING gist (geom);

DROP TABLE IF EXISTS kerb_intersection_points;
CREATE TABLE kerb_intersection_points AS
SELECT
  a.id pl_id,
  a.side,
  a."highway" AS "type",
  a."highway:name" AS "name",
  a.orientation parking_lane,
  a.position parking_lane_position,
  a.width parking_lane_width,
  a.offset parking_lane_offset,
  CASE
    WHEN (a.orientation NOT IN ('no','no_stopping','no_parking') AND b.orientation IN ('no','no_stopping','no_parking'))
      OR (a.orientation IN ('no','no_stopping','no_parking') AND b.orientation NOT IN ('no','no_stopping','no_parking')) THEN 'no_stop'
    WHEN a.highway IS NOT DISTINCT FROM b.highway
      AND a."highway:name" IS NOT DISTINCT FROM b."highway:name"
      AND a.side IS NOT DISTINCT FROM b.side
      AND a.orientation IS NOT DISTINCT FROM b.orientation
      AND a.position IS NOT DISTINCT FROM b.position THEN 'same_street'
    WHEN a."highway" IN ('pedestrian')
      OR b."highway" IN ('pedestrian') THEN 'pedestrian'
    ELSE 'other'
  END crossing_debug,
  ST_CollectionExtract(ST_Intersection(a.geog::geometry, b.geog::geometry), 1)::geography geog,
  ST_Buffer(ST_CollectionExtract(ST_Intersection(a.geog::geometry, b.geog::geometry), 1)::geography, 5) geog_buffer
FROM
  parking_lanes a,
  parking_lanes b
WHERE
  ST_Intersects(a.geog, b.geog)
  AND a.id <> b.id
  AND NOT ST_Equals(a.geog::geometry, b.geog::geometry)
;
ALTER TABLE kerb_intersection_points ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON kerb_intersection_points (id);
DROP INDEX IF EXISTS kerb_intersection_points_geog_idx;
CREATE INDEX kerb_intersection_points_geog_idx ON kerb_intersection_points USING gist (geog);
DROP INDEX IF EXISTS kerb_intersection_points_geog_buffer_idx;
CREATE INDEX kerb_intersection_points_geog_buffer_idx ON kerb_intersection_points USING gist (geog_buffer);


DROP TABLE IF EXISTS buffer_driveways;
CREATE TABLE buffer_driveways AS
SELECT
  p.id,
  (ST_Union(d.geog::geometry))::geography geog,
  ST_Multi((ST_Union(d.geog::geometry)))::geometry(MULTIPOLYGON, 4326) geom_buffer
FROM
  parking_lanes p JOIN driveways d ON st_intersects(d.geog, p.geog)
WHERE
  d.type <> 'footway'
GROUP BY
  p.id
;
CREATE UNIQUE INDEX ON buffer_driveways (id);
DROP INDEX IF EXISTS buffer_driveways_geog_idx;
CREATE INDEX buffer_driveways_geog_idx ON buffer_driveways USING gist (geog);

DROP TABLE IF EXISTS buffer_pedestrian_crossings;
CREATE TABLE buffer_pedestrian_crossings AS
SELECT
  p.id,
  (ST_Union(c.geog_offset_buffer::geometry))::geography geog,
  ST_Multi((ST_Union(c.geog_offset_buffer::geometry)))::geometry(MULTIPOLYGON, 4326) geom_buffer
FROM
  ped_crossings c JOIN parking_lanes p ON st_intersects(p.geog, c.geog_offset_buffer)
GROUP BY
  p.id
;
CREATE UNIQUE INDEX ON buffer_pedestrian_crossings (id);
DROP INDEX IF EXISTS buffer_pedestrian_crossings_geog_idx;
CREATE INDEX buffer_pedestrian_crossings_geog_idx ON buffer_pedestrian_crossings USING gist (geog);

DROP TABLE IF EXISTS buffer_kerb_intersections;
CREATE TABLE buffer_kerb_intersections AS
SELECT
  p.id,
  (ST_Union((k.geog_buffer)::geometry))::geography geog,
  ST_Multi((ST_Union((k.geog_buffer)::geometry)))::geometry(MULTIPOLYGON, 4326) geom_buffer
FROM
  kerb_intersection_points k 
  JOIN parking_lanes p ON p.geog && k.geog_buffer  -- Bounding Box Check zuerst!
WHERE
  k.crossing_debug NOT IN ('same_street')
  AND ST_Intersects(p.geog, k.geog_buffer)  -- Dann präzise Prüfung
GROUP BY
  p.id
;
CREATE UNIQUE INDEX ON buffer_kerb_intersections (id);
DROP INDEX IF EXISTS buffer_kerb_intersections_geog_idx;
CREATE INDEX buffer_kerb_intersections_geog_idx ON buffer_kerb_intersections USING gist (geog);

DROP TABLE IF EXISTS buffer_highways;
CREATE TABLE buffer_highways AS
SELECT
  p.id,
  ST_Transform((ST_Union(h.geog_buffer::geometry)),4326)::geography geog,
  ST_Multi((ST_Transform((ST_Union(h.geog_buffer::geometry)),4326)))::geometry(MULTIPOLYGON, 4326) geom_buffer
FROM
  highways h JOIN parking_lanes p ON st_intersects(p.geog, h.geog_buffer)
WHERE p.geog && h.geog_buffer
GROUP BY
  p.id
;
CREATE UNIQUE INDEX ON buffer_highways (id);
DROP INDEX IF EXISTS buffer_highways_geog_idx;
CREATE INDEX buffer_highways_geog_idx ON buffer_highways USING gist (geog);
DROP INDEX IF EXISTS buffer_highways_geom_buffer_idx;
CREATE INDEX buffer_highways_geom_buffer_idx ON buffer_highways USING gist (geom_buffer);

DROP TABLE IF EXISTS buffer_ramps;
CREATE TABLE buffer_ramps AS
SELECT
  p.id,
  (ST_Union(ST_Buffer(r.geog, 1.4)::geometry))::geography geog,
  ST_Multi((ST_Union(ST_Buffer(r.geog, 1.4)::geometry)))::geometry(MULTIPOLYGON, 4326) geom_buffer
FROM
  parking_lanes p JOIN ramps r ON st_intersects(ST_Buffer(r.geog, 1.4), p.geog)
GROUP BY
  p.id
;
CREATE UNIQUE INDEX ON buffer_ramps (id);
DROP INDEX IF EXISTS buffer_ramps_geog_idx;
CREATE INDEX buffer_ramps_geog_idx ON buffer_ramps USING gist (geog);

DROP TABLE IF EXISTS buffer_amenity_parking_points;
CREATE TABLE buffer_amenity_parking_points AS
SELECT
  p.id,
  (ST_Union(b.geog_buffer::geometry))::geography geog,
  ST_Multi((ST_Union(b.geog_buffer::geometry)))::geometry(MULTIPOLYGON, 4326) geom_buffer
FROM
  parking_lanes p JOIN amenity_parking_points b ON st_intersects(b.geog_buffer, p.geog)
GROUP BY
  p.id
;
CREATE UNIQUE INDEX ON buffer_amenity_parking_points (id);
DROP INDEX IF EXISTS buffer_amenity_parking_points_geog_idx;
CREATE INDEX buffer_amenity_parking_points_geog_idx ON buffer_amenity_parking_points USING gist (geog);

-- Buffer für Gehwegübergänge (footway=crossing + highway=footway)
-- Diese werden als Linien mit Buffer basierend auf width oder Default-Wert behandelt
DROP TABLE IF EXISTS buffer_footways_crossing;
CREATE TABLE buffer_footways_crossing AS
SELECT
  p.id,
  (ST_Union(
    ST_Buffer(
      f.geog,
      -- Buffer basierend auf width Tag oder Default-Wert (2m für Gehwegübergänge)
      -- width wird in Metern erwartet, falls vorhanden
      COALESCE(
        CASE 
          WHEN f.footway = 'crossing' THEN 2.0  -- Default für crossing
          ELSE 1.5  -- Default für andere footways
        END,
        2.0
      ),
      'endcap=flat'
    )::geometry
  ))::geography geog,
  ST_Multi((ST_Union(
    ST_Buffer(
      f.geog,
      COALESCE(
        CASE 
          WHEN f.footway = 'crossing' THEN 2.0
          ELSE 1.5
        END,
        2.0
      ),
      'endcap=flat'
    )::geometry
  )))::geometry(MULTIPOLYGON, 4326) geom_buffer
FROM
  parking_lanes p 
  JOIN footways f ON ST_Intersects(
    ST_Buffer(f.geog, 2.0, 'endcap=flat'),
    p.geog
  )
WHERE
  f.footway = 'crossing'  -- Nur footway=crossing berücksichtigen
GROUP BY
  p.id
;
CREATE UNIQUE INDEX ON buffer_footways_crossing (id);
DROP INDEX IF EXISTS buffer_footways_crossing_geog_idx;
CREATE INDEX buffer_footways_crossing_geog_idx ON buffer_footways_crossing USING gist (geog);


DROP TABLE IF EXISTS buffer_amenity_parking_poly;
CREATE TABLE buffer_amenity_parking_poly AS
SELECT
  pl.id,
  ST_Buffer(ST_Union(p.geog::geometry)::geography, 0.5)::geography geog,
  ST_Multi((ST_Union(p.geog::geometry)))::geometry(MULTIPOLYGON, 4326) geom_buffer,
  ST_Buffer(ST_Union(p.geog::geometry)::geography, 0.5)::geography geog_buffer
FROM
  parking_poly p
  -- JOIN mit parking_lanes (analog zu buffer_highways)
  JOIN parking_lanes pl ON 
    ST_Intersects(ST_Buffer(p.geog, 0.5), pl.geog)
WHERE
  -- Alle Objekte, die in parkraum.lua mit relevanten Positionen importiert wurden
  -- Die Position-Filterung erfolgt bereits beim Import (parkraum.lua Zeilen 649-652)
  -- Unterstützte Positionen: lane, street_side, shoulder, kerb_extension
  p.amenity IN ('bicycle_parking', 'motorcycle_parking', 'small_electric_vehicle_parking', 'bicycle_rental')
  AND pl.geog && ST_Buffer(p.geog, 0.5)  -- Bounding Box Check für Performance
GROUP BY
  pl.id
;
CREATE UNIQUE INDEX ON buffer_amenity_parking_poly (id);
DROP INDEX IF EXISTS buffer_amenity_parking_poly_geog_idx;
CREATE INDEX buffer_amenity_parking_poly_geog_idx ON buffer_amenity_parking_poly USING gist (geog);
DROP INDEX IF EXISTS buffer_amenity_parking_poly_geog_buffer_idx;
CREATE INDEX buffer_amenity_parking_poly_geog_buffer_idx ON buffer_amenity_parking_poly USING gist (geog_buffer);

-- Vorberechneter Buffer für parking_lanes (für pl_dev Query)
-- Wird in pl_dev Query verwendet statt ST_Buffer(p.geog, 0.5) in WHERE-Klausel
ALTER TABLE parking_lanes ADD COLUMN IF NOT EXISTS geog_buffer_05 geography;
UPDATE parking_lanes SET geog_buffer_05 = ST_Buffer(geog, 0.5) WHERE geog_buffer_05 IS NULL;
DROP INDEX IF EXISTS parking_lanes_geog_buffer_05_idx;
CREATE INDEX parking_lanes_geog_buffer_05_idx ON parking_lanes USING gist (geog_buffer_05);


DROP TABLE IF EXISTS pl_dev;
CREATE TABLE pl_dev AS
WITH direct_obstacles AS (
  -- Hindernisse die sich direkt mit der Parkfläche überschneiden
  -- Für Punkte: Nur wenn Abstand zur Parklinie < 0.45m
  -- Für Linien/Polygone: Immer
  SELECT
    p.id,
    ST_Union(ST_SetSRID(obstacle.geog, 4326)::geometry) AS obstacles_geom
  FROM
    (SELECT * FROM parking_lanes WHERE ST_GeometryType(geom) IN ('ST_LineString', 'ST_MultiLineString')) p
    LEFT JOIN highways h ON p.osm_id = h.osm_id AND p.osm_type = h.osm_type
    JOIN buffer_obstacle obstacle ON 
      ST_Intersects(p.geog, obstacle.geog)
      -- Prüfe ob Obstacle auf der gleichen Seite der Straße liegt wie die Parklinie
      AND (
        (p.side = 'left' AND h.geog_buffer_left IS NOT NULL AND ST_Intersects(h.geog_buffer_left, obstacle.geog))
        OR
        (p.side = 'right' AND h.geog_buffer_right IS NOT NULL AND ST_Intersects(h.geog_buffer_right, obstacle.geog))
        OR
        (h.geog_buffer_left IS NULL AND h.geog_buffer_right IS NULL)
      )
    LEFT JOIN LATERAL (
      SELECT op.*
      FROM obstacle_point op
      -- für Nutzung von Index
      WHERE ST_DWithin(p.geog, op.geom::geography, 0.45)
        AND ST_Distance(p.geog, op.geom::geography) < 0.45
        AND ST_Intersects(
          ST_Buffer(op.geom::geography, op.buffer)::geometry,
          obstacle.geom_buffer
        )
    ) op ON true
  GROUP BY p.id
),
snapped_obstacles AS (
  -- Punkte die >= 0.45m von Parklinie entfernt sind - werden auf Parklinie gesnappt
  SELECT
    p.id,
    ST_Union(
      ST_Buffer(
        ST_ClosestPoint(
          ST_LineMerge(p.geom),
          op.geom
        )::geography,
        op.buffer
      )::geometry
    ) AS obstacles_geom
  FROM
    (SELECT * FROM parking_lanes WHERE ST_GeometryType(geom) IN ('ST_LineString', 'ST_MultiLineString')) p
    LEFT JOIN highways h ON p.osm_id = h.osm_id AND p.osm_type = h.osm_type
    JOIN LATERAL (
      SELECT op.*
      FROM obstacle_point op
      WHERE ST_DWithin(p.geog, op.geom::geography, 15.0)
        AND ST_Distance(p.geog, op.geom::geography) >= 0.45
    ) op ON true
    -- Finde Hindernisse die zwischen Highway und Parkfläche liegen
    JOIN buffer_obstacle obstacle ON 
      ST_Intersects(
        ST_Buffer(op.geom::geography, op.buffer)::geometry,
        obstacle.geom_buffer
      )
      AND ST_DWithin(
        h.geog, 
        obstacle.geog, 
        CASE 
          WHEN p.side = 'left' THEN ABS(COALESCE(h.parking_left_offset, 0)) + 2.0
          WHEN p.side = 'right' THEN ABS(COALESCE(h.parking_right_offset, 0)) + 2.0
          ELSE ABS(COALESCE(p."offset", 0)) + 2.0
        END
      )
      -- Prüfe ob Obstacle auf der gleichen Seite der Straße liegt wie die Parklinie
      AND (
        (p.side = 'left' AND h.geog_buffer_left IS NOT NULL AND ST_Intersects(h.geog_buffer_left, obstacle.geog))
        OR
        (p.side = 'right' AND h.geog_buffer_right IS NOT NULL AND ST_Intersects(h.geog_buffer_right, obstacle.geog))
        OR
        (h.geog_buffer_left IS NULL AND h.geog_buffer_right IS NULL)
      )
  GROUP BY p.id
),
obstacles_per_lane AS (
  -- Sammle alle Hindernisse pro Parkfläche und vereinige sie
  SELECT
    p.id,
    CASE 
      WHEN direct_obs.obstacles_geom IS NOT NULL OR snapped_obs.obstacles_geom IS NOT NULL THEN 
        ST_Union(
          COALESCE(direct_obs.obstacles_geom, ST_SetSRID('GEOMETRYCOLLECTION EMPTY'::geometry, 4326)),
          COALESCE(snapped_obs.obstacles_geom, ST_SetSRID('GEOMETRYCOLLECTION EMPTY'::geometry, 4326))
        )
      ELSE 
        NULL
    END AS obstacles_geom
  FROM
    parking_lanes p
    LEFT JOIN direct_obstacles direct_obs ON p.id = direct_obs.id
    LEFT JOIN snapped_obstacles snapped_obs ON p.id = snapped_obs.id
),
unioned_geometries AS (
  SELECT
    p.id,
    ST_Union(geoms.geom) AS unioned_geom
  FROM
    parking_lanes p
    LEFT JOIN buffer_driveways d ON p.id = d.id
    LEFT JOIN buffer_ramps r ON p.id = r.id
    LEFT JOIN buffer_pedestrian_crossings c ON p.id = c.id
    LEFT JOIN buffer_kerb_intersections k ON p.id = k.id
    LEFT JOIN buffer_pt_bus b ON p.id = b.id
    LEFT JOIN buffer_pt_tram t ON p.id = t.id
    LEFT JOIN buffer_amenity_parking_points bc ON p.id = bc.id
    -- OPTIMIERUNG: Vorberechneter Buffer statt ST_Buffer in WHERE + Bounding Box Check (&&) vor ST_Intersects
    LEFT JOIN buffer_amenity_parking_poly bapp on p.geog_buffer_05 && bapp.geog_buffer AND ST_Intersects(p.geog_buffer_05, bapp.geog_buffer)
    LEFT JOIN buffer_footways_crossing fc ON p.id = fc.id
    -- OPTIMIERUNG: Bounding Box Check (&&) vor ST_Intersects
    LEFT JOIN buffer_area_highway ah on p.geog && ah.geog AND ST_Intersects(p.geog, ah.geog)
    -- Verwende die voraggregierten Hindernisse
    LEFT JOIN obstacles_per_lane opl ON p.id = opl.id
  CROSS JOIN LATERAL (
    SELECT ST_SetSRID(COALESCE(opl.obstacles_geom, 'GEOMETRYCOLLECTION EMPTY'::geometry), 4326)::geometry AS geom
    UNION ALL
    SELECT ST_SetSRID(COALESCE(ah.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
    UNION ALL
    SELECT ST_SetSRID(COALESCE(bapp.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
    UNION ALL
    SELECT ST_SetSRID(COALESCE(fc.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
    UNION ALL
    SELECT ST_SetSRID(COALESCE(bc.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
    UNION ALL
    SELECT ST_SetSRID(COALESCE(t.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
    UNION ALL
    SELECT ST_SetSRID(COALESCE(b.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
    UNION ALL
    SELECT ST_SetSRID(COALESCE(r.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
    UNION ALL
    SELECT ST_SetSRID(COALESCE(d.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
    UNION ALL
    SELECT ST_SetSRID(COALESCE(c.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
    UNION ALL
    SELECT ST_SetSRID(COALESCE(k.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
  ) AS geoms(geom)
  WHERE geoms.geom IS NOT NULL AND NOT ST_IsEmpty(geoms.geom)
  GROUP BY p.id
)
SELECT
  DISTINCT ON (p.id) p.id,
  p.osm_id,
  p.osm_type,
  p.side side,
  p.highway highway,
  p."highway:name" "highway:name",
  p.operator_type,
  p."highway:width_proc" "highway:width_proc",
  p."highway:width_proc:effective" "highway:width_proc:effective",
  p.surface surface,
  p.position position,
  p.orientation orientation,
  p.capacity_osm capacity_osm,
  p."source:capacity_osm" "source:capacity_osm",
  p.capacity capacity,
  p."source:capacity" "source:capacity",
  p.width width,
  p."offset" "offset",
  p.parking_condition,
  p.parking_condition_other,
  p.parking_condition_other_time,
  p.parking_condition_default,
  p.parking_condition_time_interval,
  p.parking_condition_maxstay,
  p.fee,
  p.fee_conditional,
  p.access,
  p.restriction,
  p.restriction_taxi,
  p.restriction_disabled,
  p.restriction_car_sharing,
  p.zone,
  p.motorcar,
  p.private,
  p.disabled,
  p.geog geog,
  --p.error_output,
  ST_Difference(
    ST_SetSRID(p.geog::geometry, 4326),
    COALESCE(ug.unioned_geom, ST_SetSRID('GEOMETRYCOLLECTION EMPTY'::geometry, 4326))
  )::geography geog_diff
FROM
  parking_lanes p
  LEFT JOIN unioned_geometries ug ON p.id = ug.id
ORDER BY
  p.id
;
CREATE UNIQUE INDEX ON pl_dev (id);

-- Optimierte pl_dev_geog Tabelle: Filtere leere Geometrien vor ST_DUMP (Performance-Optimierung)
DROP TABLE IF EXISTS pl_dev_geog;
CREATE TABLE pl_dev_geog AS
WITH defval AS (
  SELECT
    5.2 vehicle_dist_para,
    3.1 vehicle_dist_diag,
    2.5 vehicle_dist_perp,
    4.4 vehicle_length,
    1.8 vehicle_width
), dv AS (
  SELECT
    *,
    sqrt(d.vehicle_width * 0.5 * d.vehicle_width) + sqrt(d.vehicle_length * 0.5 * d.vehicle_length) vehicle_diag_width
  FROM defval d
), single_geog AS (
SELECT
    h.*,
    (ST_DUMP(h.geog_diff::geometry)).path,
    ((ST_DUMP(h.geog_diff::geometry)).geom)::geography simple_geog
FROM
  pl_dev h
WHERE
  h.geog_diff IS NOT NULL
  AND NOT ST_IsEmpty(h.geog_diff::geometry)
  AND ST_GeometryType(h.geog_diff::geometry) IN ('ST_LineString', 'ST_MultiLineString')
)
SELECT
    COALESCE((single.id::text  || '.' || single.path[1]::text), single.id::text) plid,
    single.osm_id osm_id,
    single.osm_type,
    single.side side ,
    single.highway highway ,
    single."highway:name" "highway:name",
    single.operator_type,
    single."highway:width_proc" "highway:width_proc",
    single."highway:width_proc:effective" "highway:width_proc:effective",
    single.surface surface,
    single.position position,
    -- Issue #87: Wenn orientation fehlt, aber position vorhanden ist, verwende 'parallel' als Default
    COALESCE(single.orientation, 
      CASE WHEN single.position IN ('lane', 'street_side') THEN 'parallel' 
           ELSE NULL 
      END) orientation,
    single.capacity_osm capacity_osm,
    single."source:capacity_osm" "source:capacity_osm",
    -- Kapazität wird immer basierend auf der Segmentlänge berechnet, nicht die ursprüngliche Gesamtkapazität verwenden
    -- Dies stellt sicher, dass bei aufgeteilten Parkflächen jedes Segment die korrekte Kapazität erhält
    CASE
      WHEN COALESCE(single.orientation, CASE WHEN single.position IN ('lane', 'street_side') THEN 'parallel' ELSE NULL END) = 'parallel' AND ST_Length(single.simple_geog) > dv.vehicle_length THEN floor((ST_Length(single.simple_geog) + (dv.vehicle_dist_para - dv.vehicle_length)) / dv.vehicle_dist_para)
      WHEN COALESCE(single.orientation, CASE WHEN single.position IN ('lane', 'street_side') THEN 'parallel' ELSE NULL END) = 'diagonal' AND ST_Length(single.simple_geog) > dv.vehicle_diag_width THEN floor((ST_Length(single.simple_geog) + (dv.vehicle_dist_diag - dv.vehicle_diag_width)) / dv.vehicle_dist_diag)
      WHEN COALESCE(single.orientation, CASE WHEN single.position IN ('lane', 'street_side') THEN 'parallel' ELSE NULL END) = 'perpendicular' AND ST_Length(single.simple_geog) > dv.vehicle_width THEN floor((ST_Length(single.simple_geog) + (dv.vehicle_dist_perp - dv.vehicle_width)) / dv.vehicle_dist_perp)
      ELSE 0
    END capacity,
    -- source:capacity bleibt 'estimated', da die Kapazität basierend auf Segmentlänge berechnet wird
    'estimated' "source:capacity",
    single.width width,
    single."offset" "offset",
    single.parking_condition,
    single.parking_condition_other,
    single.parking_condition_other_time,
    single.parking_condition_default,
    single.parking_condition_time_interval,
    single.parking_condition_maxstay,
    single.fee,
    single.fee_conditional,
    single.access,
    single.restriction,
    single.restriction_taxi,
    single.restriction_disabled,
    single.restriction_car_sharing,
    single.zone,
    single.motorcar,
    single.private,
    single.disabled,
    single.geog single_geog,
    --single.error_output,
    single.geog_diff geog_diff,
    (single.simple_geog)::geography geog
FROM
  single_geog single,
  dv
;
ALTER TABLE pl_dev_geog ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON pl_dev_geog (id);

DROP TABLE IF EXISTS parking_segments;
CREATE TABLE parking_segments AS
WITH defval AS (
  SELECT
    5.2 vehicle_dist_para,
    3.1 vehicle_dist_diag,
    2.5 vehicle_dist_perp,
    4.4 vehicle_length,
    1.9 vehicle_width
), dv AS (
  SELECT
    *,
    sqrt(d.vehicle_width * 0.5 * d.vehicle_width) + sqrt(d.vehicle_length * 0.5 * d.vehicle_length) vehicle_diag_width
  FROM defval d
), merged_segments AS (
  -- Issue #66: Merge segments before calculation
  -- Segmente mit gleichen parking-Tags werden vor der Kapazitätsberechnung zusammengeführt
  -- Dies verhindert, dass kleine Segmente (z.B. durch Einfahrten getrennt) verloren gehen
  SELECT
    -- Gruppierungs-Attribute
    -- Cross-Way Merging: Array aller osm_ids + MIN für Kompatibilität
    array_agg(DISTINCT pl.osm_id) AS osm_ids,
    MIN(pl.osm_id) AS osm_id,
    pl.osm_type,
    pl.side,
    pl.position,
    COALESCE(pl.orientation, 
      CASE WHEN pl.position IN ('lane', 'street_side') THEN 'parallel' 
           ELSE NULL 
      END) AS orientation,
    pl.highway,
    pl."highway:name" highway_name,
    pl.operator_type,
    pl."highway:width_proc" highway_width_proc,
    pl."highway:width_proc:effective" highway_width_proc_effective,
    pl.surface,
    -- Cross-Way Merging: capacity_osm summieren wenn beide Segmente capacity_osm haben
    SUM(pl.capacity_osm) AS capacity_osm,
    MAX(pl."source:capacity_osm") AS source_capacity_osm,
    pl.width,
    pl."offset",
    pl.parking_condition,
    pl.parking_condition_other,
    pl.parking_condition_other_time,
    pl.parking_condition_default,
    pl.parking_condition_time_interval,
    pl.parking_condition_maxstay,
    pl.fee,
    pl.fee_conditional,
    pl.access,
    pl.restriction,
    pl.restriction_taxi,
    pl.restriction_disabled,
    pl.restriction_car_sharing,
    pl.zone,
    pl.motorcar,
    pl.private,
    pl.disabled,
    
    -- Geometrie zusammenführen
    ST_LineMerge(ST_Union(pl.geog::geometry))::geography AS merged_geog,
    
    -- Metadaten
    COUNT(*) AS original_segment_count,
    SUM(ST_Length(pl.geog)) AS merged_length
    
  FROM pl_dev_geog pl, dv
  WHERE
    ST_Length(pl.geog) > 1.7
    AND (pl.position NOT IN ('separate') OR pl.position IS NULL)
  GROUP BY
    -- Cross-Way Merging: Gruppiere nach highway_name (mit Fallback auf highway) statt osm_id
    COALESCE(pl."highway:name", pl.highway),
    pl.osm_type,
    pl.side,
    pl.position,
    COALESCE(pl.orientation, 
      CASE WHEN pl.position IN ('lane', 'street_side') THEN 'parallel' 
           ELSE NULL 
      END),
    pl.highway,
    pl."highway:name",
    pl.operator_type,
    pl."highway:width_proc",
    pl."highway:width_proc:effective",
    pl.surface,
    pl.width,
    pl."offset",
    pl.parking_condition,
    pl.parking_condition_other,
    pl.parking_condition_other_time,
    pl.parking_condition_default,
    pl.parking_condition_time_interval,
    pl.parking_condition_maxstay,
    pl.fee,
    pl.fee_conditional,
    pl.access,
    pl.restriction,
    pl.restriction_taxi,
    pl.restriction_disabled,
    pl.restriction_car_sharing,
    pl.zone,
    pl.motorcar,
    pl.private,
    pl.disabled
), segments_with_lengths AS (
  SELECT
    ms.osm_type,
    ms.osm_id,
    ms.side,
    ms.highway,
    ms.highway_name,
    ms.operator_type,
    ms.highway_width_proc,
    ms.highway_width_proc_effective,
    ms.surface,
    ms.position,
    ms.orientation,
    ms.capacity_osm,
    ms.source_capacity_osm,
    ms.width,
    ms."offset",
    ms.parking_condition,
    ms.parking_condition_other,
    ms.parking_condition_other_time,
    ms.parking_condition_default,
    ms.parking_condition_time_interval,
    ms.parking_condition_maxstay,
    ms.fee,
    ms.fee_conditional,
    ms.access,
    ms.restriction,
    ms.restriction_taxi,
    ms.restriction_disabled,
    ms.restriction_car_sharing,
    ms.zone,
    ms.motorcar,
    ms.private,
    ms.disabled,
    ms.merged_geog AS geog,
    ST_Length(ms.merged_geog) AS segment_length,
    -- Gesamtlänge: Bei merged segments ist das bereits die merged_length
    ms.merged_length AS total_length,
    -- Berechnete Kapazität basierend auf merged Länge
    CASE
      WHEN ms.orientation = 'parallel' AND ST_Length(ms.merged_geog) > dv.vehicle_length THEN round((ST_Length(ms.merged_geog) + (dv.vehicle_dist_para - dv.vehicle_length)) / dv.vehicle_dist_para)
      WHEN ms.orientation = 'diagonal' AND ST_Length(ms.merged_geog) > dv.vehicle_diag_width THEN round((ST_Length(ms.merged_geog) + (dv.vehicle_dist_diag - dv.vehicle_diag_width)) / dv.vehicle_dist_diag)
      WHEN ms.orientation = 'perpendicular' AND ST_Length(ms.merged_geog) > dv.vehicle_width THEN round((ST_Length(ms.merged_geog) + (dv.vehicle_dist_perp - dv.vehicle_width)) / dv.vehicle_dist_perp)
      ELSE NULL
    END capacity_calculated
  FROM merged_segments ms, dv
  WHERE
    ST_Length(ms.merged_geog) > 1.7
), segments_with_capacity AS (
  SELECT
    *,
    -- Wenn capacity_osm vorhanden ist: verteile proportional zur Segmentlänge
    -- Sonst: verwende berechnete Kapazität
    CASE
      WHEN capacity_osm IS NOT NULL AND total_length > 0 THEN
        GREATEST(1, round(capacity_osm * (segment_length / total_length)))
      ELSE capacity_calculated
    END capacity,
    -- source:capacity ist 'OSM' wenn capacity_osm verwendet wurde, sonst 'estimated'
    CASE
      WHEN capacity_osm IS NOT NULL AND total_length > 0 THEN 'OSM'
      ELSE 'estimated'
    END source_capacity
  FROM segments_with_lengths
), segments_with_geom AS (
  SELECT
    *,
    -- Try to merge to LineString first
    ST_LineMerge(geog::geometry) AS merged_geom
  FROM segments_with_capacity
), segments_with_dumped_geom AS (
  -- Extrahiere ALLE Segmente aus MultiLineString
  -- Dies verhindert, dass Segmente durch Einfahrten getrennt verloren gehen
  SELECT
    swg.*,
    dumped.path[1] AS segment_index,
    dumped.geom::geometry(LineString, 4326) AS geom,
    ST_Length(dumped.geom::geography) AS segment_geom_length,
    -- Berechne Kapazität für jedes Segment neu basierend auf seiner Länge
    CASE
      WHEN swg.orientation = 'parallel' AND ST_Length(dumped.geom::geography) > dv.vehicle_length THEN 
        round((ST_Length(dumped.geom::geography) + (dv.vehicle_dist_para - dv.vehicle_length)) / dv.vehicle_dist_para)
      WHEN swg.orientation = 'diagonal' AND ST_Length(dumped.geom::geography) > dv.vehicle_diag_width THEN 
        round((ST_Length(dumped.geom::geography) + (dv.vehicle_dist_diag - dv.vehicle_diag_width)) / dv.vehicle_dist_diag)
      WHEN swg.orientation = 'perpendicular' AND ST_Length(dumped.geom::geography) > dv.vehicle_width THEN 
        round((ST_Length(dumped.geom::geography) + (dv.vehicle_dist_perp - dv.vehicle_width)) / dv.vehicle_dist_perp)
      ELSE NULL
    END AS segment_capacity_calculated,
    -- Wenn capacity_osm vorhanden ist: verteile proportional zur Segmentlänge
    CASE
      WHEN swg.capacity_osm IS NOT NULL AND swg.total_length > 0 THEN
        GREATEST(1, round(swg.capacity_osm * (ST_Length(dumped.geom::geography) / swg.total_length)))
      ELSE NULL
    END AS segment_capacity_osm
  FROM segments_with_geom swg, dv
  CROSS JOIN LATERAL (
    SELECT 
      (ST_Dump(
        CASE 
          WHEN ST_GeometryType(swg.merged_geom) = 'ST_MultiLineString' THEN
            swg.merged_geom
          ELSE
            swg.merged_geom::geometry(MultiLineString, 4326)
        END
      )).path,
      (ST_Dump(
        CASE 
          WHEN ST_GeometryType(swg.merged_geom) = 'ST_MultiLineString' THEN
            swg.merged_geom
          ELSE
            swg.merged_geom::geometry(MultiLineString, 4326)
        END
      )).geom::geometry(LineString, 4326) AS geom
  ) dumped
  WHERE ST_GeometryType(swg.merged_geom) = 'ST_MultiLineString'
), segments_with_longest_geom AS (
  -- Für LineString: verwende direkt
  SELECT
    swg.osm_type,
    swg.osm_id,
    swg.side,
    swg.highway,
    swg.highway_name,
    swg.operator_type,
    swg.highway_width_proc,
    swg.highway_width_proc_effective,
    swg.surface,
    swg.position,
    swg.orientation,
    swg.capacity_osm,
    swg.source_capacity_osm,
    swg.capacity,
    swg.source_capacity,
    swg.width,
    swg."offset",
    swg.parking_condition,
    swg.parking_condition_other,
    swg.parking_condition_other_time,
    swg.parking_condition_default,
    swg.parking_condition_time_interval,
    swg.parking_condition_maxstay,
    swg.fee,
    swg.fee_conditional,
    swg.access,
    swg.restriction,
    swg.restriction_taxi,
    swg.restriction_disabled,
    swg.restriction_car_sharing,
    swg.zone,
    swg.motorcar,
    swg.private,
    swg.disabled,
    swg.segment_length,
    swg.total_length,
    swg.capacity_calculated,
    swg.merged_geom::geometry(LineString, 4326) AS geom,
    swg.merged_geom::geography AS geog
  FROM segments_with_geom swg
  WHERE ST_GeometryType(swg.merged_geom) = 'ST_LineString'
  UNION ALL
  -- Alle Segmente aus MultiLineString mit neu berechneter Kapazität
  SELECT
    swdg.osm_type,
    swdg.osm_id,
    swdg.side,
    swdg.highway,
    swdg.highway_name,
    swdg.operator_type,
    swdg.highway_width_proc,
    swdg.highway_width_proc_effective,
    swdg.surface,
    swdg.position,
    swdg.orientation,
    swdg.capacity_osm,
    swdg.source_capacity_osm,
    -- Verwende neu berechnete Kapazität für dieses Segment
    COALESCE(swdg.segment_capacity_osm, swdg.segment_capacity_calculated) AS capacity,
    CASE
      WHEN swdg.segment_capacity_osm IS NOT NULL THEN 'OSM'
      ELSE 'estimated'
    END AS source_capacity,
    swdg.width,
    swdg."offset",
    swdg.parking_condition,
    swdg.parking_condition_other,
    swdg.parking_condition_other_time,
    swdg.parking_condition_default,
    swdg.parking_condition_time_interval,
    swdg.parking_condition_maxstay,
    swdg.fee,
    swdg.fee_conditional,
    swdg.access,
    swdg.restriction,
    swdg.restriction_taxi,
    swdg.restriction_disabled,
    swdg.restriction_car_sharing,
    swdg.zone,
    swdg.motorcar,
    swdg.private,
    swdg.disabled,
    swdg.segment_geom_length AS segment_length,
    swdg.total_length,
    swdg.segment_capacity_calculated AS capacity_calculated,
    swdg.geom,
    swdg.geom::geography AS geog
  FROM segments_with_dumped_geom swdg
)
SELECT
    osm_type,
    osm_id,
    side,
    highway,
    highway_name,
    operator_type,
    highway_width_proc,
    highway_width_proc_effective,
    surface,
    position,
    orientation,
    capacity_osm,
    source_capacity_osm,
    capacity,
    source_capacity "source:capacity",
    width,
    "offset",
    segment_length "length",
    segment_length / NULLIF(COALESCE(capacity, 1), 0) length_per_capacity,
	CASE
		--WHEN position IN ('separate') THEN 'not_processed_yet'
		-- Zuerst prüfen, ob Daten fehlen (höchste Priorität)
		WHEN position IS NULL THEN 'data_missing'
		-- Issue #87: orientation wird jetzt auf 'parallel' gesetzt, wenn position vorhanden ist
		-- Daher wird data_missing_orientation nicht mehr benötigt für lane/street_side
		WHEN position IN ('street_side', 'lane') AND capacity IS NULL THEN 'segment_too_small'
		WHEN position IN ('street_side', 'lane') THEN 'processed'
		WHEN position IN ('no') THEN 'no_parking'
		WHEN position NOT IN ('no','separate') AND capacity IS NULL THEN 'segment_too_small'
		WHEN capacity IS NULL THEN 'data_missing'
		ELSE 'other'
	END capacity_status,
    -- Issue #86: Attribut für Art des Parkplatzes (öffentlich/kunden/anwohner)
    -- Für Liniendaten: Default = "Öffentlicher Parkplatz" wenn kein access (außer operator_type=private)
    CASE
        -- Öffentlicher Parkplatz: access=yes ODER motorcar=yes|designated (auch wenn access=no)
        WHEN access = 'yes' OR motorcar IN ('yes', 'designated') THEN 'public'
        -- Kundenparkplatz: access=customers
        WHEN access = 'customers' THEN 'customers'
        -- Anwohnerparkplatz: access=private + private=residents
        WHEN access = 'private' AND private = 'residents' THEN 'residents'
        -- Mitarbeiterparkplatz: access=private + private=employees
        WHEN access = 'private' AND private = 'employees' THEN 'employees'
        -- Gewerbeparkplatz: access=private + private=commercial
        WHEN access = 'private' AND private = 'commercial' THEN 'commercial'
        -- Anwohnerparkplatz: access=private (ohne private-Tag, wird durch condition_class 'residents' ergänzt)
        WHEN access = 'private' THEN 'residents'
        -- Sonstiger/Unbestimmter: wenn operator_type=private und kein access
        WHEN access IS NULL AND operator_type = 'private' THEN 'other'
        -- Öffentlicher Parkplatz: Default für Liniendaten wenn kein access angegeben
        WHEN access IS NULL THEN 'public'
        -- Sonstiger/Unbestimmter: alles andere
        ELSE 'other'
    END parking_access_type,
    -- condition_class Berechnung basierend auf Issue #80
    -- Als Array, da mehrere Werte gleichzeitig auftreten können
    ARRAY_REMOVE(ARRAY[
        -- Basiswerte (gegenseitig ausschließend - nur einer wird gesetzt)
        CASE
            -- mixed: Parkgebühr fällig UND Parkzone getaggt
            WHEN position IN ('lane', 'street_side') 
                AND (fee IN ('yes', 'interval') OR fee_conditional IS NOT NULL) 
                AND zone IS NOT NULL THEN 'mixed'
            -- residents: privater access UND Parkzone getaggt
            WHEN position IN ('lane', 'street_side') 
                AND access = 'private' 
                AND zone IS NOT NULL 
                AND NOT (fee IN ('yes', 'interval') OR fee_conditional IS NOT NULL) THEN 'residents'
            -- paid: Parkgebühr fällig UND keine Parkzone getaggt
            WHEN position IN ('lane', 'street_side') 
                AND (fee IN ('yes', 'interval') OR fee_conditional IS NOT NULL) 
                AND zone IS NULL THEN 'paid'
            -- free: Keine Parkgebühr UND keine Parkzone getaggt
            WHEN position IN ('lane', 'street_side') 
                AND (fee IS NULL OR fee = 'no') 
                AND fee_conditional IS NULL 
                AND zone IS NULL 
                AND access != 'private' THEN 'free'
            ELSE NULL
        END,
        -- Zusätzliche Werte (kombinierbar)
        CASE WHEN parking_condition = 'loading_only' OR restriction = 'loading_only' THEN 'loading' END,
        CASE WHEN parking_condition = 'charging_only' OR restriction = 'charging_only' THEN 'charging' END,
        CASE WHEN parking_condition = 'disabled' AND access = 'private' THEN 'disabled_private' END,
        CASE WHEN parking_condition_maxstay IS NOT NULL THEN 'time_limited' END,
        CASE WHEN (parking_condition = 'disabled' OR restriction_disabled IS NOT NULL) 
            AND NOT (parking_condition = 'disabled' AND access = 'private') THEN 'disabled' END,
        CASE WHEN parking_condition = 'taxi' OR restriction_taxi IS NOT NULL THEN 'taxi' END,
        CASE WHEN parking_condition = 'car_sharing' OR restriction_car_sharing IS NOT NULL THEN 'car_sharing' END,
        CASE WHEN restriction IS NOT NULL 
            AND restriction NOT IN ('loading_only', 'charging_only')
            AND restriction_taxi IS NULL 
            AND restriction_disabled IS NULL 
            AND restriction_car_sharing IS NULL THEN 'vehicle_restriction' END,
        CASE WHEN access IS NOT NULL AND access != 'private' AND access != 'yes' THEN 'access_restriction' END,
        CASE WHEN parking_condition = 'no_parking' OR parking_condition_other = 'no_parking' THEN 'no_parking' END,
        CASE WHEN parking_condition = 'no_stopping' OR parking_condition_other = 'no_stopping' THEN 'no_stopping' END
    ], NULL) condition_class,
    --error_output,
    geom,
    geog
FROM segments_with_longest_geom
;
ALTER TABLE parking_segments ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON parking_segments (id);
DROP INDEX IF EXISTS parking_segments_geom_idx;
CREATE INDEX parking_segments_geom_idx ON parking_segments USING gist (geom);
DROP INDEX IF EXISTS parking_segments_geog_idx;
CREATE INDEX parking_segments_geog_idx ON parking_segments USING gist (geog);


DROP TABLE IF EXISTS parking_segments_label;
CREATE TABLE parking_segments_label AS
SELECT
    id,
    osm_type,
    osm_id,
    side,
    highway,
    highway_name,
    operator_type,
    highway_width_proc,
    highway_width_proc_effective,
    surface,
    position,
    orientation,
    capacity_osm,
    source_capacity_osm,
    capacity,
    "source:capacity",
    width,
    "offset",
    "length",
    length_per_capacity,
    degrees(ST_Azimuth(ST_StartPoint(ST_Transform(geom, 3857)), ST_EndPoint(ST_Transform(geom, 3857)))) -90  angle,
    CASE
      WHEN side = 'left' THEN
        ST_Transform(
          ST_SetSRID(
            ST_MakePoint(
              ST_X(ST_Transform((ST_LineInterpolatePoint(geom, 0.5))::geometry(Point, 4326), 3857)) + (-6 * cosd(degrees(ST_Azimuth(ST_StartPoint(ST_Transform(geom, 3857)), ST_EndPoint(ST_Transform(geom, 3857)))))),
              ST_Y(ST_Transform((ST_LineInterpolatePoint(geom, 0.5))::geometry(Point, 4326), 3857)) + (6 * sind(degrees(ST_Azimuth(ST_StartPoint(ST_Transform(geom, 3857)), ST_EndPoint(ST_Transform(geom, 3857))))))
            ),
            3857
          ),
          4326
      )
      WHEN side = 'right' THEN
        ST_Transform(
          ST_SetSRID(
            ST_MakePoint(
              ST_X(ST_Transform((ST_LineInterpolatePoint(geom, 0.5))::geometry(Point, 4326), 3857)) + (6 * cosd(degrees(ST_Azimuth(ST_StartPoint(ST_Transform(geom, 3857)), ST_EndPoint(ST_Transform(geom, 3857)))))),
              ST_Y(ST_Transform((ST_LineInterpolatePoint(geom, 0.5))::geometry(Point, 4326), 3857)) + (-6 * sind(degrees(ST_Azimuth(ST_StartPoint(ST_Transform(geom, 3857)), ST_EndPoint(ST_Transform(geom, 3857))))))
            ),
            3857
          ),
          4326
      )
	  END geom
FROM parking_segments
WHERE
  capacity IS NOT NULL
;
CREATE UNIQUE INDEX ON parking_segments_label (id);
ALTER TABLE parking_segments_label ALTER COLUMN geom TYPE geometry(Point, 4326) USING ST_Transform(geom, 4326);
DROP INDEX IF EXISTS parking_segments_label_geom_idx;
CREATE INDEX parking_segments_label_geom_idx ON parking_segments_label USING gist (geom);


DROP TABLE IF EXISTS parking_spaces;
CREATE TABLE parking_spaces AS
WITH multi AS (
  SELECT
      id,
      osm_type,
      osm_id,
      side,
      highway,
      "highway:name" highway_name,
      operator_type,
      "highway:width_proc" highway_width_proc,
      "highway:width_proc:effective" highway_width_proc_effective,
      surface,
      orientation,
      "position",
      capacity_osm,
      "source:capacity_osm" source_capacity_osm,
      capacity,
      "source:capacity" source_capacity,
      width,
      "offset",
      --error_output,
      CASE
        WHEN orientation = 'diagonal' THEN degrees(ST_Azimuth(ST_Startpoint(ST_Transform(geog::geometry, 25832)), ST_EndPoint(ST_Transform(geog::geometry, 25832)))) + 45
        WHEN orientation = 'perpendicular' THEN degrees(ST_Azimuth(ST_Startpoint(ST_Transform(geog::geometry, 25832)), ST_EndPoint(ST_Transform(geog::geometry, 25832)))) + 90
        ELSE degrees(ST_Azimuth(ST_Startpoint(ST_Transform(geog::geometry, 25832)), ST_EndPoint(ST_Transform(geog::geometry, 25832))))
      END angle,
      CASE
        WHEN capacity IS NOT NULL AND capacity > 0 AND 1 / capacity BETWEEN 0 AND 1 THEN
          ST_Multi(ST_LineInterpolatePoints(geog::geometry(LineString, 4326), 1 / capacity, true))::geometry(Multipoint, 4326)
        ELSE 'POINT EMPTY'::geometry
      END geom
  FROM pl_dev_geog
  WHERE
    ST_Length(geog) > 1.7
    --AND capacity IS NOT NULL
  )
SELECT
      osm_id,
      side,
      highway,
      highway_name,
      highway_width_proc,
      highway_width_proc_effective,
      surface,
      orientation,
      "position",
      capacity_osm,
      source_capacity_osm,
      capacity,
      source_capacity,
      width,
      "offset",
      --error_output,
      angle,
      ((ST_DUMP(geom)).geom)::geometry(Point, 4326) AS geom
FROM
  multi
;
ALTER TABLE parking_spaces ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON parking_spaces (id);
DROP INDEX IF EXISTS parking_spaces_geom_idx;
CREATE INDEX parking_spaces_geom_idx ON parking_spaces USING gist (geom);


DROP TABLE IF EXISTS  highways_admin;
CREATE TABLE highways_admin AS
SELECT
  DISTINCT ON (h.id, b.name, b.admin_level) h.id highway_id,
  h.osm_id,
  h.osm_type,
  b.name admin_name,
  b.admin_level,
  h.type,
  h.surface,
  h.name,
  h.operator_type,
  h.oneway,
  h.service,
  h.dual_carriageway,
  h.lanes,
  h.parking_left_position,
  h.parking_right_position,
  h.parking_left_orientation,
  h.parking_right_orientation,
  h.parking_width_proc,
  h.parking_width_proc_effective,
  h.parking_left_width,
  h.parking_right_width,
  h.parking_left_width_carriageway,
  h.parking_right_width_carriageway,
  h.parking_left_offset,
  h.parking_right_offset,
  h.parking_left_capacity,
  h.parking_right_capacity,
  h.parking_left_source_capacity,
  h.parking_right_source_capacity,
  ST_Intersection(h.geom, b.geom) geom
FROM
  boundaries b,
  highways h
WHERE
  h.geog && b.geog
  AND h.type NOT IN ('pedestrian')
ORDER BY
  h.id, b.name, b.admin_level
;
DELETE FROM highways_admin WHERE ST_GeometryType(geom) NOT IN ('ST_LineString', 'ST_MultiLineString');
ALTER TABLE highways_admin ALTER COLUMN geom TYPE geometry(MultiLinestring, 4326) USING ST_Transform(ST_Multi(geom), 4326);
ALTER TABLE highways_admin ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON highways_admin (id);
CREATE INDEX ON boundaries (admin_level);
ALTER TABLE highways_admin ADD COLUMN IF NOT EXISTS geog geography(MultiLineString, 4326);
UPDATE highways_admin SET geog = geom::geography;
CREATE INDEX highways_admin_geog_idx ON highways_admin USING gist (geog);
CREATE INDEX highways_admin_geom_idx ON highways_admin USING gist (geom);

DROP TABLE IF EXISTS boundaries_stats;
CREATE TABLE boundaries_stats AS
WITH base_stats AS (
  SELECT
    b.name,
    b.admin_level,
    ROUND(ST_Area(b.geog)::numeric / (1000 * 1000), 2)  area_sqkm,
    COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IN ('street_side') OR parking_right_position IN ('street_side'))))::numeric / 1000, 1), 0) +
    COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IN ('street_side') OR parking_right_position IN ('street_side'))))::numeric / 1000, 1), 0) AS street_side_km,

    COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IN ('lane') OR parking_right_position IN ('lane'))))::numeric / 1000, 1), 0) +
    COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IN ('lane') OR parking_right_position IN ('lane'))))::numeric / 1000, 1), 0) AS lane_km,

    COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IN ('on_kerb') OR parking_right_position IN ('on_kerb'))))::numeric / 1000, 1), 0) +
    COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IN ('on_kerb') OR parking_right_position IN ('on_kerb'))))::numeric / 1000, 1), 0) AS on_kerb_km,

    COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IN ('half_on_kerb') OR parking_right_position IN ('half_on_kerb'))))::numeric / 1000, 1), 0) +
    COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IN ('half_on_kerb') OR parking_right_position IN ('half_on_kerb'))))::numeric / 1000, 1), 0) AS half_on_kerb_km,

    COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IS NULL OR parking_right_position IS NULL)))::numeric / 1000, 1), 0) +
    COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IS NULL OR parking_right_position IS NULL)))::numeric / 1000, 1), 0) AS d_other_km,

    COALESCE(ROUND((SUM(ST_Length(h.geog)) / 1000)::numeric, 1), 0) AS length_wo_dual_carriageway,
    b.geog::geometry(MultiPolygon, 4326) geom
  FROM
    boundaries b,
    highways_admin h
  WHERE
    ST_Intersects(h.geog, b.geog)
    AND h.geog && b.geog
    AND h.admin_level = b.admin_level
    AND h.admin_level IN (4, 9, 10)
    AND h.type IN ('primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link', 'residential', 'unclassified', 'living_street', 'pedestrian', 'road')
    AND b.name NOT IN ('Gosen', 'Lindenberg', 'Schönerlinde')
  GROUP BY
    b.name, b.admin_level, b.geog
)
SELECT
  name,
  admin_level,
  area_sqkm,
  street_side_km,
  lane_km,
  on_kerb_km,
  half_on_kerb_km,
  d_other_km,
  (street_side_km + lane_km + on_kerb_km + half_on_kerb_km + d_other_km) AS sum_km,
  length_wo_dual_carriageway,
  geom
FROM
  base_stats
ORDER BY
  name
;
ALTER TABLE boundaries_stats ADD COLUMN IF NOT EXISTS done_percent numeric;
UPDATE boundaries_stats SET done_percent = ROUND((street_side_km + lane_km) / NULLIF(sum_km, 0) * 100, 1);
ALTER TABLE boundaries_stats ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON boundaries_stats (id);
CREATE INDEX IF NOT EXISTS boundaries_stats_geom_idx ON boundaries_stats USING gist (geom);
CREATE INDEX IF NOT EXISTS boundaries_stats_admin_level_idx ON boundaries_stats(admin_level);


DROP TABLE IF EXISTS boundaries_stats_short;
CREATE TABLE boundaries_stats_short AS
WITH pre1 as (
  SELECT
    admin_name as admin_name,
    admin_level,
    parking_left_position as pos,
    (SUM(ST_Length(geog)) FILTER (WHERE dual_carriageway IS NULL )) + ((SUM(ST_Length(geog)) FILTER (WHERE dual_carriageway = true )) / 2) as laenge
  FROM highways_admin
  WHERE type IN ('primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link', 'residential', 'unclassified', 'living_street', 'pedestrian, road')
  GROUP BY parking_left_position, admin_name, admin_level
  UNION
  SELECT
    admin_name as admin_name,
    admin_level,
    parking_right_position as pos,
    (SUM(ST_Length(geog)) FILTER (WHERE dual_carriageway IS NULL )) + ((SUM(ST_Length(geog)) FILTER (WHERE dual_carriageway = true )) / 2) as laenge
  FROM highways_admin
  WHERE type IN ('primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link', 'residential', 'unclassified', 'living_street', 'pedestrian, road')
  GROUP BY parking_right_position, admin_name, admin_level
)
, pre2 as (
SELECT
  admin_name,
  admin_level,
  pos,
  round(laenge::numeric / 1000, 1) laenge_km,
  round((100 * laenge / Sum(laenge) OVER ())::numeric, 1) AS laenge_percent
FROM (
    SELECT
    admin_name,
    admin_level,
    pos,
    Sum(laenge) AS laenge
    FROM pre1
    GROUP BY pos, admin_name, admin_level
    ) posi
)
SELECT
  p.admin_name, p.admin_level,
  SUM(p.laenge_km) FILTER (WHERE p.pos IS NOT NULL) as length_done_km,
  SUM(p.laenge_km) FILTER (WHERE p.pos IS NULL) as length_notdone_km,
  SUM(p.laenge_km) FILTER (WHERE p.pos IN ('street_side')) as street_side_km,
  SUM(p.laenge_km) FILTER (WHERE p.pos IN ('lane')) as lane_km,
  SUM(p.laenge_km) FILTER (WHERE p.pos IN ('on_kerb')) as on_kerb_km,
  SUM(p.laenge_km) FILTER (WHERE p.pos IN ('half_on_kerb')) as half_on_kerb_km,
  round(SUM(p.laenge_km) FILTER (WHERE p.pos IS NOT NULL) / NULLIF((SUM(p.laenge_km) FILTER (WHERE p.pos IS NOT NULL) + SUM(p.laenge_km) FILTER (WHERE p.pos IS NULL)), 0) * 100, 1)  as done_percent,
  ST_Transform(b.geom, 4326) geom
FROM pre2 p
     LEFT JOIN boundaries b ON (b.name, b.admin_level) = (p.admin_name, p.admin_level)
GROUP BY p.admin_name, p.admin_level, b.geom
ORDER BY p.admin_level, p.admin_name
;

ALTER TABLE boundaries_stats_short ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON boundaries_stats_short (id);
DROP INDEX IF EXISTS boundaries_stats_short_geom_idx;
CREATE INDEX boundaries_stats_short_geom_idx ON boundaries_stats_short USING gist (geom);

