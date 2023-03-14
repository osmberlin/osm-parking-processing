# osm-parking-processing

This project is based on [strassenraumkarte-neukoelln](https://github.com/SupaplexOSM/strassenraumkarte-neukoelln)  and 
an attempt to process all the data for any city. 

There are two parts of this project:

1) process OpenStreetMap data and create a database

   Osmium is used to filter OSM data, osm2pgsql is used to import osm data to the database. Currently, db_scripts.sql is 
   work in progress, all tables, names are in a development state and could be renamed or removed in the future.
2) visualize the processed data

   QGis is used for visualizing the results. The QGis project files is configured to load all the geo data 
   (all gpkg, geojson). It is used to compare the results with the upstream project.


## Requirements

### software
* [git](https://git-scm.com/)
* [Docker](https://www.docker.com/) and docker-compose
* [QGis](https://qgis.org) 
This setup makes use of the following software:
* [osm2pgsql](https://osm2pgsql.org/) >=1.8.1
* [osmium-tool](https://osmcode.org/osmium-tool/) >= 1.14 
* [PostgreSQL](https://www.postgresql.org/) >= 13 
* [PostGIS](https://postgis.net/) >= 3.3 
* [pg_tileserv](https://github.com/CrunchyData/pg_tileserv)
* [pg_featureserve](https://github.com/CrunchyData/pg_featureserv)
* [Varnish](https://varnish-cache.org/)

### settings
- use template files in sub folders (`*_template`) to create a `.env` files by copying/renaming it
- create spatial filter as geojson file in `data` directory (or copy `extracts/boundaries/berlin.geojson` to filter 
  Berlin) the name of the file will be used as name of this region.
- download OSM data and put the file in the `osm` folder
  ```sh
  wget -q http://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf -O osm/berlin-latest.osm.pbf
  ```
- you can put multiple pbf files in osm/ directory. They will get merged and imported. This way multiple regions 
  can be imported. You have to make sure the pbf files contain data from the same timestamp. This setup will try 
  to update the osm data to the latest changesets before importing it. If you put a month-old file in there, it will 
  take some time.

If you want to create your own extracts, there is another [readme.md](extracts/readme.md) you can follow.

### run services

```bash
git pull https://github.com/osmberlin/osm-parking-processing.git
cd osm-parking-processing

docker-compose up -d parking_db
#wait until db is ready
docker-compose logs -f --timestamp parking_db

docker-compose up -d parking_import
#wait until data is imported and updater caught up
docker-compose logs -f --timestamp parking_import

docker-compose up -d parking_processing
#wait until processing is done (service restarts every two hours)
docker-compose logs -f --timestamp parking_processing

docker-compose up -d parking_vt parking_cache
```

WIP: Usually you would just start all services with docker-compose up. Since the import and processing takes a while 
and the sync & wait between the containers isn't implemented yet, it is better to manually start the services.

some usefull commands:
- start container `docker-compose start`
- stop container `docker-compose stop`
- see log messages `docker-compose logs`
- see stats `docker stats`
- remove container `docker-compose rm -f parking_import parking_processing parking_vt parking_db`
- cleanup (almost) everything `docker system prune --volumes`

### access services

Access to the database 
psql -h localhost -p 5431 -U docker -d docker
Access to the vector tile service http://localhost:7800
Access to the cache is provided by port 6085

If you run a nginx webserver, you can use the following configuration:

```
server {
   listen 80;
   listen [::]:80;

    server_name vts.your.host;

    add_header Access-Control-Allow-Origin *;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_pass http://127.0.0.1:6085/;
    }

    error_log /var/log/nginx/vts_error.log;
    access_log /var/log/nginx/vts_access.log;

}
```

### output formats

The vector tile server `pg_tileserv` publishes all available tables, which fulfill the [requirements](https://github.com/CrunchyData/pg_tileserv#table-layers).
So keep in mind that you want to check what data you really want to publish. As for now all intermediate tables are being published, even if there is no use for it now.
The important tables are 

| name | content                                                       |
|----|---------------------------------------------------------------|
| all buffer_* tables | all the calculated buffer used for cutting out parking spaces |
| parking_segments | smallest part of a street with parking information            |
| parking_lanes | representing the OSM highway line with a offset               |
| parking_spaces | calculated points representing a parking spot                 |

They have these attributes:

| parking_segments | paking_lanes | parking_spaces |
| --- | --- | --- |
| id | id | id | 
| osm_type | osm_type | osm_type | 
| osm_id | osm_id | osm_id | 
| side | side | side | 
| highway | highway | highway | 
| highway_name | highway_name | highway_name | 
| highway_width_proc | highway_width_proc | highway_width_proc | 
| highway_width_proc_effective | highway_width_proc_effective | highway_width_proc_effective | 
| surface | surface | surface | 
| position | position | position | 
| orientation | orientation | orientation | 
| capacity_osm | capacity_osm | capacity_osm | 
| source_capacity_osm | source_capacity_osm | source_capacity_osm | 
| capacity | capacity | capacity | 
| source_capacity | source_capacity | source_capacity | 
| width | width | width | 
| offset | offset | offset | 
| length | | angle |
| length_per_capacity | | |
| capacity_status | | |
| error_output | error_output | error_output |

Each of them is exported as Geopackage file and pushed to `parking_processing/export/{region_name}/dataset_name_{region_name}.gpkg`.

For each imported region statistics per administrative boundary are generated and exported as `geojson` file to the 
directory `parking_processing/export/{region_name}/region_{region_name}.geojson`. the `{region_name}` gets extracted from the 
boundary import files you copy to the `data` directory.

## Prototype fund

The [German Federal Ministry of Education and Research](https://www.bmbf.de/) sponsored this project as part of the [Prototype Fund (08/2022 to 02/2023)](https://prototypefund.de/project/parkraumdaten-aus-openstreetmap-prozessierung-und-visualisierung/). [Blogpost…](https://parkraum.osm-verkehrswende.org/posts/2022-09-01-prototype-fund)

![Logo Prototype Fund](https://parkraum.osm-verkehrswende.org/images/prototype-fund/logo-prototype-fund.svg) ![Logo Bundesministerium für Bildung und Forschung](https://parkraum.osm-verkehrswende.org/images/prototype-fund/logo-bmbf.svg)
