FROM debian:sid-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    gdal-bin \
    jq \
    lua-dkjson \
    osmctools \
    osmium-tool \
    postgresql-client-15 \
    pyosmium \
    python3-psycopg2 \
    osm2pgsql

# clean up
RUN apt-get remove --yes wget && \
    apt-get autoremove --yes && \
    apt-get clean --yes && \
    rm -rf /var/lib/apt/* /var/cache/apt/* /root/.cache

COPY ./.pg_service.conf /root/.pg_service.conf

WORKDIR /osm
CMD ["/bin/bash", "-i", "/config/import_osm.sh"]
