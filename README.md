# strassenraum-berlin

This project is based on https://github.com/SupaplexOSM/strassenraumkarte-neukoelln and an attempt to process all the data for any city. 

It is highly work in progress, be carefull when running scripts!

There are two parts of this project:

1) process OpenStreetMap data and create a database

Osmium is used to filter OSM data, osm2pgsql is used to import osm data to the database. Currently db_scripts.sql is work in progress, all tables, names are in a development state and could be renamed or removed in the future.

2) visualize the processed data

QGis is used for visualizing the results. The QGis project files is configured to load all the geo data (all gpkg, geojson). It is used to compare the results with the upstream project.



## Requirements

### software
- git, lua-dkjson
- osm2pgsql >=1.6  https://osm2pgsql.org/
- osmium-tool >= 1.14 https://osmcode.org/osmium-tool/
- PostgreSQL >= 13 https://www.postgresql.org/
- PostGIS >= 3.1 https://postgis.net/
- QGis https://qgis.org

### settings
- create DB and DB-user
- configure authentication, use .pg_service.conf, see https://www.cybertec-postgresql.com/en/pg_service-conf-the-forgotten-config-file/

### osm2pgsql
- build osm2pgsql  https://github.com/openstreetmap/osm2pgsql#building

```
git clone git://github.com/openstreetmap/osm2pgsql.git
mkdir build && cd build
cmake ..
(cmake -D WITH_LUAJIT=ON ..)
make
```

- download osm
> wget -q http://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf -O openstreetmap-latest.osm.pbf

- filter osm file
> osmium tags-filter -O -o openstreetmap-filtered.osm.pbf -e filter-expressions.txt openstreetmap-latest.osm.pbf

- import filtered osm file into db
> osm2pgsql -c -O flex -S highways.lua openstreetmap-filtered.osm.pbf

- create additional db tables
> psql -f db_scripts.sql

