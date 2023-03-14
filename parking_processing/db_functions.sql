--https://trac.osgeo.org/postgis/ticket/2192
--TODO accept geography type AS parameter
CREATE OR REPLACE FUNCTION ST_Splap(geom1 geometry, geom2 geometry, double precision)
  RETURNS geometry AS 'SELECT ST_Split(ST_Snap($1, $2, $3), $2)'
  LANGUAGE sql IMMUTABLE STRICT COST 10;
