FROM debian:sid-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    postgresql-client-15 \
    gdal-bin

# clean up
RUN rm -rf /var/lib/apt/lists/*

COPY ./.pg_service.conf /root/.pg_service.conf
WORKDIR /osm
CMD ["/bin/bash", "-i", "/config/process_osm.sh"]
