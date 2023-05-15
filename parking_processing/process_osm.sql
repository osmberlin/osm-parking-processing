SET SEARCH_PATH TO processing, public;

DROP TABLE IF EXISTS amenity_parking_points;
DROP TABLE IF EXISTS boundaries;
DROP TABLE IF EXISTS buffer_area_highway;
DROP TABLE IF EXISTS buffer_obstacle_poly;
DROP TABLE IF EXISTS crossings;
DROP TABLE IF EXISTS footways;
DROP TABLE IF EXISTS highways;
DROP TABLE IF EXISTS obstacle_point;
DROP TABLE IF EXISTS parking_poly;
DROP TABLE IF EXISTS pt_platform;
DROP TABLE IF EXISTS pt_stops;
DROP TABLE IF EXISTS ramps;
DROP TABLE IF EXISTS service;
DROP TABLE IF EXISTS traffic_calming_points;

CREATE TABLE amenity_parking_points AS SELECT * FROM import.amenity_parking_points;
CREATE TABLE boundaries AS SELECT * FROM import.boundaries;
CREATE TABLE buffer_area_highway AS SELECT * FROM import.area_highway;
CREATE TABLE buffer_obstacle_poly AS SELECT * FROM import.obstacle_poly;
CREATE TABLE crossings AS SELECT * FROM import.crossings;
CREATE TABLE footways AS SELECT * FROM import.footways;
CREATE TABLE highways AS SELECT * FROM import.highways;
CREATE TABLE obstacle_point AS SELECT * FROM import.obstacle_point;
CREATE TABLE parking_poly AS SELECT * FROM import.parking_poly;
CREATE TABLE pt_platform AS SELECT * FROM import.pt_platform;
CREATE TABLE pt_stops AS SELECT * FROM import.pt_stops;
CREATE TABLE ramps AS SELECT * FROM import.ramps;
CREATE TABLE service AS SELECT * FROM import.service;
CREATE TABLE traffic_calming_points AS SELECT * FROM import.traffic_calming_points;

-- insert highway=service into highways table when there are parking information
INSERT INTO highways
  (osm_type, osm_id, id, type, geom, surface, name, oneway, operator_type, parking_left_orientation, parking_left_offset, parking_left_position, parking_left_width, parking_left_width_carriageway, parking_right_orientation, parking_right_offset, parking_right_position, parking_right_width, parking_right_width_carriageway, parking_width_proc, parking_width_proc_effective)
SELECT
  osm_type, osm_id, id, type, geom, surface, name, oneway, operator_type, parking_left_orientation, parking_left_offset, parking_left_position, parking_left_width, parking_left_width_carriageway, parking_right_orientation, parking_right_offset, parking_right_position, parking_right_width, parking_right_width_carriageway, parking_width_proc, parking_width_proc_effective
FROM
  service
WHERE
  (parking_left_position IN ('lane', 'street_side') OR parking_right_position IN ('lane', 'street_side'))
  AND service IS DISTINCT FROM 'parking_aisle'
  AND (parking_left_orientation IN ('diagonal', 'marked', 'parallel', 'perpendicular', 'separate', 'yes')
  OR parking_right_orientation IN ('diagonal', 'marked', 'parallel', 'perpendicular', 'separate', 'yes'))
;

ALTER TABLE highways DROP COLUMN id;
ALTER TABLE highways ADD COLUMN id SERIAL PRIMARY KEY;

CREATE UNIQUE INDEX ON amenity_parking_points (id);
CREATE UNIQUE INDEX ON boundaries (id);
CREATE UNIQUE INDEX ON buffer_area_highway (id);
CREATE UNIQUE INDEX ON buffer_obstacle_poly (id);
CREATE UNIQUE INDEX ON crossings (id);
CREATE UNIQUE INDEX ON footways (id);
CREATE UNIQUE INDEX ON highways (id);
CREATE UNIQUE INDEX ON obstacle_point (id);
CREATE UNIQUE INDEX ON parking_poly (id);
CREATE UNIQUE INDEX ON pt_stops (id);
CREATE UNIQUE INDEX ON ramps (id);
CREATE UNIQUE INDEX ON service (id);
CREATE UNIQUE INDEX ON traffic_calming_points (id);

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

ALTER TABLE obstacle_point ADD COLUMN IF NOT EXISTS geog_buffer geography;
UPDATE obstacle_point SET geog_buffer = ST_Buffer(geom::geography, buffer);
ALTER TABLE obstacle_point ADD COLUMN IF NOT EXISTS geom_buffer geography;
UPDATE obstacle_point SET geom_buffer = (ST_Buffer(geom::geography, buffer))::geometry(Polygon, 4326);
DROP INDEX IF EXISTS obstacle_point_geog_buffer_idx;
CREATE INDEX obstacle_point_geog_buffer_idx ON obstacle_point USING gist (geog_buffer);
DROP INDEX IF EXISTS obstacle_point_geom_buffer_idx;
CREATE INDEX obstacle_point_geom_buffer_idx ON obstacle_point USING gist (geom_buffer);

ALTER TABLE buffer_obstacle_poly ADD COLUMN IF NOT EXISTS geog geography;
UPDATE buffer_obstacle_poly SET geog = ST_Buffer(geom::geography, buffer, 'endcap=flat');
ALTER TABLE buffer_obstacle_poly ADD COLUMN IF NOT EXISTS geom geography;
UPDATE buffer_obstacle_poly SET geom = (ST_Buffer(geom::geography, buffer, 'endcap=flat'))::geometry(Polygon, 4326);
DROP INDEX IF EXISTS buffer_obstacle_poly_geog_idx;
CREATE INDEX buffer_obstacle_poly_geog_idx ON buffer_obstacle_poly USING gist (geog);
DROP INDEX IF EXISTS buffer_obstacle_poly_geom_idx;
CREATE INDEX buffer_obstacle_poly_geom_idx ON buffer_obstacle_poly USING gist (geom);

-- ALTER TABLE trees ADD COLUMN IF NOT EXISTS geog geography(Point, 4326);
-- UPDATE trees SET geog = geom::geography;
-- ALTER TABLE trees ADD COLUMN IF NOT EXISTS geog_buffer geography;
-- UPDATE trees SET geog_buffer = ST_Buffer(geog, 1);
-- DROP INDEX IF EXISTS trees_geog_buffer_idx;
-- CREATE INDEX trees_geog_buffer_idx ON trees USING gist (geog_buffer);

ALTER TABLE boundaries ADD COLUMN IF NOT EXISTS geog geography(MultiPolygon, 4326);
UPDATE boundaries SET geog = ST_Multi(geom)::geography;
ALTER TABLE boundaries ALTER COLUMN geom TYPE geometry(MultiPolygon, 25833) USING ST_Multi(ST_Transform(geom, 25833));
DROP INDEX IF EXISTS boundaries_geom_idx;
CREATE INDEX boundaries_geom_idx ON boundaries USING gist (geom);
DROP INDEX IF EXISTS boundaries_geog_idx;
CREATE INDEX boundaries_geog_idx ON boundaries USING gist (geog);

ALTER TABLE parking_poly ADD COLUMN IF NOT EXISTS geog geography;
UPDATE parking_poly SET geog = geom::geography;
DROP INDEX IF EXISTS parking_poly_geog_idx;
CREATE INDEX parking_poly_geog_idx ON parking_poly USING gist (geog);

ALTER TABLE buffer_area_highway ADD COLUMN IF NOT EXISTS geog geography(Polygon, 4326);
UPDATE buffer_area_highway SET geog = ST_Buffer(geog, 2, 'join=bevel');
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
        parking,
        building,
        operator_type,
        parking_orientation,
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
    h1.type,
    array_agg(DISTINCT h1.osm_id) osm_id,
    (ST_LineMerge(ST_UNION(h1.geog::geometry))) AS geom
  FROM highways h1, highways h2
  WHERE
    h1.type NOT LIKE '%_link'
    AND ST_Intersects(h1.geog, h2.geog)
    AND h1.id <> h2.id
    AND h1.name IS NOT NULL
  GROUP BY h1.name, h1.type
)
SELECT
  h.name highway_name,
  h.osm_id,
  h.type,
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
DROP INDEX IF EXISTS highway_union_geog_idx;
CREATE INDEX highway_union_geog_idx ON highway_union USING gist (geog);
DROP INDEX IF EXISTS highway_union_geog_buffer_left_idx;
CREATE INDEX highway_union_geog_buffer_idx ON highway_union USING gist (geog_buffer);
DROP INDEX IF EXISTS highway_union_geog_buffer_idx;
CREATE INDEX highway_union_geog_buffer_left_idx ON highway_union USING gist (geog_buffer_left);
DROP INDEX IF EXISTS highway_union_geog_buffer_right_idx;
CREATE INDEX highway_union_geog_buffer_right_idx ON highway_union USING gist (geog_buffer_right);

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


-- DROP TABLE IF EXISTS highway_segments;
-- CREATE TABLE highway_segments AS
-- WITH crossing_intersecting_highways AS(
--    SELECT
--      h.id AS lines_id,
--      h.highway_name AS highway_name,
--      h.geog AS line_geog,
--      (ST_Union(c.geog::geometry))::geography AS blade
--    FROM highway_union h, highway_crossings c
--    WHERE h.geog && c.geog_buffer
--    GROUP BY h.id, h.highway_name, h.type, h.geog
-- )
-- SELECT
--   lines_id,
--   highway_name,
--   --todo let ST_Splap accept geography
--   ((ST_Dump(ST_Splap(line_geog::geometry, blade::geometry, 0.0000000000001))).geom)::geography geog
-- FROM
--   crossing_intersecting_highways
-- WHERE
--     ST_GeometryType(blade::geometry) IN ('ST_Point', 'ST_MultiPoint')
-- ;
-- ALTER TABLE highway_segments ADD COLUMN id SERIAL PRIMARY KEY;
-- CREATE UNIQUE INDEX ON highway_segments (id);
-- ALTER TABLE highway_segments ADD COLUMN IF NOT EXISTS geog_buffer_left geography;
-- UPDATE highway_segments SET geog_buffer_left = ST_Buffer(geog, 8, 'side=left endcap=flat');
-- ALTER TABLE highway_segments ADD COLUMN IF NOT EXISTS geog_buffer_right geography;
-- UPDATE highway_segments SET geog_buffer_right = ST_Buffer(geog, 8, 'side=right endcap=flat');
-- ALTER TABLE highway_segments ADD COLUMN IF NOT EXISTS geog_buffer geography;
-- UPDATE highway_segments SET geog_buffer = ST_Buffer(geog, 8, 'endcap=flat');
--
-- DROP INDEX IF EXISTS highway_segments_geog_buffer_left_idx;
-- CREATE INDEX highway_segments_geog_buffer_left_idx ON highway_segments USING gist (geog_buffer_left);
-- DROP INDEX IF EXISTS highway_segments_geog_buffer_right_idx;
-- CREATE INDEX highway_segments_geog_buffer_right_idx ON highway_segments USING gist (geog_buffer_right);
-- DROP INDEX IF EXISTS highway_segments_geog_buffer_idx;
-- CREATE INDEX highway_segments_geog_buffer_idx ON highway_segments USING gist (geog_buffer);


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
  CASE
    -- before offsetting we cut out all separated parking lanes
    WHEN v.side IN ('left') THEN
      ST_Transform(
        ST_OffsetCurve(
          ST_Transform(
            ST_Difference(
              a.geog::geometry,
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
              a.geog::geometry,
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
-- UNION ALL
-- SELECT
--   h.way_id way_id,
--   pl.side,
--   h.type highway,
--   h.name "highway:name",
--   h.operator_type,
--   NULL "highway:width_proc",
--   NULL "highway:width_proc:effective",
--   NULL surface,
--   p.parking position,
--   p.parking_orientation "orientation",
--   p.capacity capacity_osm,
--   'OSM' "source:capacity_osm",
--   CASE
--     WHEN p.capacity IS NULL THEN GREATEST(1, floor(ST_Area(p.geog) / 12.2))
--     ELSE p.capacity
--   END capacity,
--   CASE
--     WHEN p.capacity IS NULL THEN 'estimated'
--     ELSE 'OSM'
--   END "source:capacity",
--   NULL width,
--   CASE
--     WHEN pl.side = 'left' THEN h.parking_left_offset
--     WHEN pl.side = 'right' THEN h.parking_right_offset
--   END "offset",
--   CASE
--     WHEN pl.side = 'left' THEN ST_Transform(ST_OffsetCurve(ST_Simplify(ST_Transform(ST_LineMerge(pl.geog::geometry), 25833), (ST_Length(ST_Transform(ST_LineMerge(pl.geog::geometry), 25833)) * 0.1)), h.parking_left_offset), 4326)::geography
--     WHEN pl.side = 'right' THEN ST_Transform(ST_OffsetCurve(ST_Simplify(ST_Transform(ST_LineMerge(pl.geog::geometry), 25833), (ST_Length(ST_Transform(ST_LineMerge(pl.geog::geometry), 25833)) * 0.1)), h.parking_right_offset), 4326)::geography
--   END geog,
--   'GEOMETRYCOLLECTION EMPTY'::geography geog_shorten,
--   '{}'::jsonb error_output
-- FROM
--   pl_separated pl
--   LEFT JOIN parking_poly p ON p.id = pl.pp_id
--   JOIN LATERAL (
--     SELECT
--       h.*
--     FROM
--       highways h
--     WHERE
--       h.geog_buffer_right && p.geog
--       OR h.geog_buffer_left && p.geog
--     ORDER BY
--       --order by biggest intersection area
--       ST_Area(ST_Intersection(h.geog_buffer_right, p.geog)) + ST_Area(ST_Intersection(h.geog_buffer_left, p.geog)) DESC,
--       --afterwards by smallest distance
--       p.geog <-> h.geog
--     LIMIT 1
--   ) AS h ON true
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
  "offset"
  --error_output
;
ALTER TABLE parking_lanes ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX parking_lanes_pk_idx ON parking_lanes USING btree (id ASC NULLS LAST);
DROP INDEX IF EXISTS parking_lanes_geom_idx;
CREATE INDEX parking_lanes_geom_idx ON parking_lanes USING gist (geom);
DROP INDEX IF EXISTS parking_lanes_geog_idx;
CREATE INDEX parking_lanes_geog_idx ON parking_lanes USING gist (geog);

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

DROP TABLE IF EXISTS buffer_obstacle_point;
CREATE TABLE buffer_obstacle_point AS
SELECT
  p.id,
  ST_Multi(ST_Union((ST_Buffer((st_closestpoint(p.geom, o.geom))::geography, o.buffer))::geometry))::geography geog
FROM
  parking_lanes p JOIN obstacle_point o ON ST_Intersects(p.geog, ST_Buffer(o.geom::geography, 5))
GROUP BY
  p.id
;
DROP INDEX IF EXISTS buffer_obstacle_point_geog_idx;
CREATE INDEX buffer_obstacle_point_geog_idx ON buffer_obstacle_point USING gist (geog);



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
  kerb_intersection_points k JOIN parking_lanes p ON st_intersects(p.geog, k.geog_buffer)
WHERE
  k.crossing_debug NOT IN ('same_street')
  AND p.geog && k.geog_buffer
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


DROP TABLE IF EXISTS buffer_amenity_parking_poly;
CREATE TABLE buffer_amenity_parking_poly AS
SELECT
  p.id,
  ST_Union(p.geog::geometry)::geography geog,
  ST_Multi((ST_Union(p.geog::geometry)))::geometry(MULTIPOLYGON, 4326) geom_buffer
FROM
  parking_poly p
WHERE
    p.amenity = 'bicycle_parking'
GROUP BY
  p.id
;
CREATE UNIQUE INDEX ON buffer_amenity_parking_poly (id);
DROP INDEX IF EXISTS buffer_amenity_parking_poly_geog_idx;
CREATE INDEX buffer_amenity_parking_poly_geog_idx ON buffer_amenity_parking_poly USING gist (geog);


DROP TABLE IF EXISTS pl_dev;
CREATE TABLE pl_dev AS
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
  p.geog geog,
  --p.error_output,
  ST_Difference(
    ST_Difference(
      ST_Difference(
        ST_Difference(
          ST_Difference(
            ST_Difference(
              ST_Difference(
                ST_Difference(
                 ST_Difference(
                     ST_Difference(
                       ST_Difference(
                         ST_Difference(
                          p.geog::geometry,
                          ST_SetSRID(COALESCE(ob_poly.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
                            ),
                        ST_SetSRID(COALESCE(ob_point.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
                          ),
                      ST_SetSRID(COALESCE(ah.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
                        ),
                      ST_SetSRID(COALESCE(bapp.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
                    ),
                  ST_SetSRID(COALESCE(bc.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
                ),
                ST_SetSRID(COALESCE(t.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
              ),
              ST_SetSRID(COALESCE(b.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
            ),
            ST_SetSRID(COALESCE(r.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
          ),
          ST_SetSRID(COALESCE(d.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
        ),
        ST_SetSRID(COALESCE(c.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
      ),
      ST_SetSRID(COALESCE(k.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
    ),
    ST_SetSRID(COALESCE(hb.geog, 'GEOMETRYCOLLECTION EMPTY'::geography), 4326)::geometry
  )::geography geog_diff
--   d.geog driveway_geog,
--   c.geog ped_crossing_geog,
--   k.geog kerbs_geog,
--   hb.geog highways_buffer_geog,
--   r.geog ramps_geog,
--   b.geog bus_geog,
--   t.geog tram_geog,
--   bc.geog bike_geog,
--   bapp.geog pp_geog,
--   ah.geog_buffer area_highway_geog
FROM
  parking_lanes p
  LEFT JOIN buffer_driveways d ON p.id = d.id
  LEFT JOIN buffer_ramps r ON p.id = r.id
  LEFT JOIN buffer_pedestrian_crossings c ON p.id = c.id
  LEFT JOIN buffer_kerb_intersections k ON p.id = k.id
  LEFT JOIN buffer_pt_bus b ON p.id = b.id
  LEFT JOIN buffer_pt_tram t ON p.id = t.id
  LEFT JOIN buffer_highways hb ON p.id = hb.id
  LEFT JOIN buffer_amenity_parking_points bc ON p.id = bc.id
  LEFT JOIN buffer_amenity_parking_poly bapp on ST_Intersects(p.geog, bapp.geog)
  LEFT JOIN buffer_area_highway ah on ST_Intersects(p.geog, ah.geog)
  LEFT JOIN buffer_obstacle_poly ob_poly on ST_Intersects(p.geog, ob_poly.geog)
  LEFT JOIN buffer_obstacle_point ob_point on ST_Intersects(p.geog, ob_point.geog)
ORDER BY
  p.id
;
CREATE UNIQUE INDEX ON pl_dev (id);

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
    single.orientation orientation,
    single.capacity_osm capacity_osm,
    single."source:capacity_osm" "source:capacity_osm",
    CASE
      WHEN side = 'left' AND single.capacity IS NOT NULL AND single.capacity <> 0 THEN single.capacity
      WHEN side = 'left' AND single.capacity IS NULL OR single.capacity = 0 THEN
        CASE
          WHEN single.orientation = 'parallel' AND ST_Length(single.simple_geog) > dv.vehicle_length THEN floor((ST_Length(single.simple_geog) + (dv.vehicle_dist_para - dv.vehicle_length)) / dv.vehicle_dist_para)
          WHEN single.orientation = 'diagonal' AND ST_Length(single.simple_geog) > dv.vehicle_diag_width THEN floor((ST_Length(single.simple_geog) + (dv.vehicle_dist_diag - dv.vehicle_diag_width)) / dv.vehicle_dist_diag)
          WHEN single.orientation = 'perpendicular' AND ST_Length(single.simple_geog) > dv.vehicle_width THEN floor((ST_Length(single.simple_geog) + (dv.vehicle_dist_perp - dv.vehicle_width)) / dv.vehicle_dist_perp)
        END
      WHEN side = 'right' AND single.capacity IS NOT NULL AND single.capacity <> 0 THEN single.capacity
      WHEN side = 'right' AND single.capacity IS NULL OR single.capacity = 0 THEN
        CASE
          WHEN single.orientation = 'parallel' AND ST_Length(single.simple_geog) > dv.vehicle_length THEN floor((ST_Length(single.simple_geog) + (dv.vehicle_dist_para - dv.vehicle_length)) / dv.vehicle_dist_para)
          WHEN single.orientation = 'diagonal' AND ST_Length(single.simple_geog) > dv.vehicle_diag_width THEN floor((ST_Length(single.simple_geog) + (dv.vehicle_dist_diag - dv.vehicle_diag_width)) / dv.vehicle_dist_diag)
          WHEN single.orientation = 'perpendicular' AND ST_Length(single.simple_geog) > dv.vehicle_width THEN floor((ST_Length(single.simple_geog) + (dv.vehicle_dist_perp - dv.vehicle_width)) / dv.vehicle_dist_perp)
        END
    END capacity,
    CASE
      WHEN single.capacity IS NOT NULL AND single.capacity <> 0 THEN single."source:capacity"
      WHEN single.capacity IS NULL OR single.capacity = 0 THEN 'estimated'
    END "source:capacity",
    single.width width,
    single."offset" "offset",
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
SELECT
    osm_type,
    osm_id,
    side,
    highway,
    "highway:name" highway_name,
    operator_type,
    "highway:width_proc" highway_width_proc,
    "highway:width_proc:effective" highway_width_proc_effective,
    surface,
    position,
    orientation,
    capacity_osm,
    "source:capacity_osm" source_capacity_osm,
    capacity,
    "source:capacity" source_capacity,
    width,
    "offset",
    ST_Length(geog) "length",
    ST_Length(geog) / COALESCE(capacity, 1) length_per_capacity,
	CASE
		WHEN position IN ('separate') THEN 'not_processed_yet'
		WHEN position IN ('no') THEN 'no_parking'
		WHEN position NOT IN ('no','separate') AND capacity IS NULL THEN 'segment_too_small'
		WHEN capacity IS NULL THEN 'data_missing'
		ELSE 'other'
	END capacity_status,
    --error_output,
    geog::geometry(LineString, 4326) geom,
    geog
FROM pl_dev_geog
WHERE
  ST_Length(geog) > 1.7
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
    source_capacity,
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
        WHEN  1 / capacity BETWEEN 0 AND 1 THEN
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
  ST_Intersection(h.geom, b.geom) geom,
  ST_Intersection(h.geog, b.geog) geog
FROM
  boundaries b,
  highways h
WHERE
  h.geog && b.geog
  AND b.admin_level IN (4, 9, 10)
  AND h.type IN ('primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link', 'residential', 'unclassified', 'living_street', 'pedestrian, road')
ORDER BY
  h.id, b.name, b.admin_level
;
DELETE FROM highways_admin WHERE ST_GeometryType(geom) NOT IN ('ST_LineString', 'ST_MultiLineString');
ALTER TABLE highways_admin ALTER COLUMN geom TYPE geometry(MultiLinestring, 4326) USING ST_Transform(ST_Multi(geom), 4326);
ALTER TABLE highways_admin ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON highways_admin (id);
DROP INDEX IF EXISTS highways_admin_geom_idx;
CREATE INDEX highways_admin_geom_idx ON highways_admin USING gist (geom);
DROP INDEX IF EXISTS highways_admin_geog_idx;
CREATE INDEX highways_admin_geog_idx ON highways_admin USING gist (geog);

DROP TABLE IF EXISTS boundaries_stats;
CREATE TABLE boundaries_stats AS
SELECT
  b.name,
  b.admin_level,
  ROUND(ST_Area(b.geog)::numeric / (1000 * 1000), 2)  area_sqkm,
  COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IN ('street_side') OR parking_right_position IN ('street_side'))))::numeric / 1000, 1), 0) +
  COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IN ('street_side') OR parking_right_position IN ('street_side'))))::numeric / 1000, 1), 0) AS street_side_km,

  COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IN ('lane') OR parking_right_position IN ('lane'))))::numeric / 1000, 1), 0) +
  COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IN ('lane') OR parking_right_position IN ('lane'))))::numeric / 1000, 1), 0) AS lane_km,

  COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IS NULL OR parking_right_position IS NULL)))::numeric / 1000, 1), 0) +
  COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IS NULL OR parking_right_position IS NULL)))::numeric / 1000, 1), 0) AS d_other_km,

  COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IN ('street_side') OR parking_right_position IN ('street_side'))))::numeric / 1000, 1), 0) +
  COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IN ('street_side') OR parking_right_position IN ('street_side'))))::numeric / 1000, 1), 0) +
  COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IN ('lane') OR parking_right_position IN ('lane'))))::numeric / 1000, 1), 0) +
  COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IN ('lane') OR parking_right_position IN ('lane'))))::numeric / 1000, 1), 0) +
  COALESCE(ROUND((SUM(ST_Length(h.geog)) FILTER (WHERE dual_carriageway IS NULL AND (parking_left_position IS NULL OR parking_right_position IS NULL)))::numeric / 1000, 1), 0) +
  COALESCE(ROUND((SUM(ST_Length(h.geog) / 2) FILTER (WHERE dual_carriageway = true AND (parking_left_position IS NULL OR parking_right_position IS NULL)))::numeric / 1000, 1), 0) AS sum_km,
  ROUND((SUM(ST_Length(h.geog)) / 1000)::numeric, 1) "length_wo_dual_carriageway",
  b.geog::geometry(MultiPolygon, 4326) geom
FROM
  boundaries b,
  highways_admin h
WHERE
  ST_Intersects(ST_Transform((h.geog)::geometry, 25833), b.geom)
  AND h.admin_level = b.admin_level
  AND h.admin_level IN (4, 9, 10)
  AND h.type IN ('primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link', 'residential', 'unclassified', 'living_street', 'pedestrian, road')
  AND b.name NOT IN ('Gosen', 'Lindenberg', 'Schönerlinde')
GROUP BY
  b.name, b.admin_level, b.geog
ORDER BY
  b.name
;
ALTER TABLE boundaries_stats ADD COLUMN id SERIAL PRIMARY KEY;
CREATE UNIQUE INDEX ON boundaries_stats (id);
DROP INDEX IF EXISTS boundaries_stats_geom_idx;
CREATE INDEX boundaries_stats_geom_idx ON boundaries_stats USING gist (geom);
ALTER TABLE boundaries_stats ADD COLUMN IF NOT EXISTS done_percent numeric;
UPDATE boundaries_stats SET done_percent = ROUND((street_side_km + lane_km) / NULLIF(sum_km, 0) * 100, 1);
