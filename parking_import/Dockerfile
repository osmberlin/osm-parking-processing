FROM debian:sid-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    gdal-bin \
    jq \
    lua-dkjson \
    osmctools \
    osmium-tool \
    postgresql-client \
    pyosmium \
    python3-psycopg2 \
    osm2pgsql \
    exim4-config- \
    exim4-base- \
    exim4-daemon-light- \
    bsd-mailx-

# clean up
RUN apt-get remove --yes wget && \
    apt-get autoremove --yes && \
    apt-get clean --yes && \
    rm -rf /var/lib/apt/* /var/cache/apt/* /root/.cache

COPY ./.pg_service.conf /root/.pg_service.conf

WORKDIR /osm
CMD ["/bin/bash", "-i", "/config/import_osm.sh"]
