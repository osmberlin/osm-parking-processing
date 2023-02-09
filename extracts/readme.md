# How to create extracts from OpenStreetMap

To import data for your city you need to create an extract from a OpenStreetMap PBF file, which covers your whole city 
or area of interest. You might be lucky and can already download an area which fits your needs from one of the services 
listed in the [OSM wiki](https://wiki.openstreetmap.org/wiki/Planet.osm#Country_and_area_extracts).  

If you want to create your own extract you need the following parts:

- the [osmium-extract](https://docs.osmcode.org/osmium/latest/osmium-extract.html) tool 
  from the [osmium-tool](https://osmcode.org/osmium-tool/)box  
- a boundary file in geojson format (other formats are also supported by osmium)
- a OpenStreetMap file which covers your area of interest completely. You could use the 
  whole [planet file](https://planet.osm.org/), but probably you only need a country extract, 
  which you can get from [Geofabrik](https://download.geofabrik.de/) or [bbbike.org](https://download.bbbike.org/osm/).

Within this repository there are example files provided as well as a configuration file `extracts.json`. 
To run the osmium-extract tool you can use the following command (if you downloaded the europe-extract):

`osmium extract -v --overwrite -c extracts.json europe-latest.osm.pbf`

The individual extracts defined within the config file will be placed inside the output directory.
