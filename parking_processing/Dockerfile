FROM debian:sid-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    postgresql-client-15 \
    gdal-bin \
    python3-gdal \
    python3-geopandas \
    python3-sqlalchemy

# clean up
RUN rm -rf /var/lib/apt/lists/*

#RUN pip install argparse geopandas sqlalchemy

COPY ./.pg_service.conf /root/.pg_service.conf
COPY ./export_data.py /config/export_data.py
WORKDIR /osm
CMD ["/bin/bash", "-i", "/config/process_osm.sh"]
