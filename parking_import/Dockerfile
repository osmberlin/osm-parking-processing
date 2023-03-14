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
    python3-psycopg2

RUN apt-get install -y \
    git \
    make \
    cmake \
    g++ \
    libboost-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libexpat1-dev \
    zlib1g-dev \
    libbz2-dev \
    libpq-dev \
    libproj-dev \
    lua5.3 \
    liblua5.3-dev \
    pandoc

ENV HOME /root
ENV OSM2PGSQL_VERSION master

RUN mkdir src &&\
    cd src &&\
    git clone --depth 1 --branch ${OSM2PGSQL_VERSION} https://github.com/openstreetmap/osm2pgsql.git &&\
    cd osm2pgsql &&\
    mkdir build &&\
    cd build &&\
    cmake .. &&\
    make &&\
    make install &&\
    cd /root &&\
    rm -rf src

# clean up
RUN apt-get remove --yes wget && \
    apt-get autoremove --yes && \
    apt-get clean --yes && \
    rm -rf /var/lib/apt/* /var/cache/apt/* /root/.cache

COPY ./.pg_service.conf /root/.pg_service.conf

WORKDIR /osm
CMD ["/bin/bash", "-i", "/config/import_osm.sh"]
