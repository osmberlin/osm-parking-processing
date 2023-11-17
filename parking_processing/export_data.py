import argparse
import os
from argparse import ArgumentParser

import geopandas as gpd
import sqlalchemy as sa

# create argument parser
parser: ArgumentParser = argparse.ArgumentParser()

# add arguments
parser.add_argument(
    '--output_file_name', type=str,
    help='path and name of output file', default='output.gpkg')
parser.add_argument(
    '--table_name', type=str,
    help='name of table to be queried', default='processing.parking_segments')
parser.add_argument(
    '--region_name', type=str,
    help='name of region to be processed', default='berlin')

# parse arguments
args = parser.parse_args()

# Get the service name from the PGSERVICE environment variable
pg_service_name = os.environ.get("PGSERVICE")

# Check if PGSERVICE environment variable is set
if not pg_service_name:
    print('Error: PGSERVICE environment variable not set')
    exit()

# Connect to Postgres
engine = sa.create_engine(f"postgresql+psycopg2:///?service={pg_service_name}")

# TODO use explicit column names or catch all
# define query
query = '''
SELECT 
  p.*,
  s."label" as "label"
FROM {table_name} as p, meta.spatialfilter s 
WHERE 
  s.name = '{region_name}' 
  AND ST_Intersects(p.geom, s.geom) 
'''.format(table_name=args.table_name, region_name=args.region_name)

# create geopandas dataframe directly from query
gdf = gpd.read_postgis(sql=query, con=engine, geom_col='geom')

output_file_path = args.output_file_name

# check if file exists...
if os.path.exists(output_file_path):
    # if yes, remove it. we don't want to append data to an old file
    os.remove(output_file_path)

# export DataFrame to file
gdf.to_file(output_file_path, driver='GPKG')
