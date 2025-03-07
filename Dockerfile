# Public OSRM docker image is too old, apt is not working
FROM debian:bookworm-slim AS builder

RUN apt update && apt install -y \
    wget \
    build-essential \
    zlib1g-dev \
    tar \
    git \
    cmake \
    libboost-all-dev \
    libtbb-dev \
    libstxxl-dev \
    libxml2-dev \
    libosmpbf-dev \
    libbz2-dev \
    libprotobuf-dev \
    libluajit-5.1-dev \
    liblua5.1-0-dev \
    lua5.1 \
    pkg-config

WORKDIR /downloads
RUN wget https://download.geofabrik.de/russia-latest.osm.pbf -O russia.osm.pbf

WORKDIR /osrm-bin
RUN wget https://github.com/Project-OSRM/osrm-backend/releases/download/v5.27.1/node_osrm-v5.27.1-node-v108-linux-x64-Release.tar.gz -O osrm.tar.gz
RUN tar -xf osrm.tar.gz && rm osrm.tar.gz

RUN git clone --single-branch --branch v5.27.1 https://github.com/Project-OSRM/osrm-backend /osrm

WORKDIR /downloads
RUN /osrm-bin/binding/osrm-extract -p /osrm/profiles/car.lua /downloads/russia.osm.pbf
RUN /osrm-bin/binding/osrm-partition /downloads/russia.osrm
RUN /osrm-bin/binding/osrm-customize /downloads/russia.osrm
RUN rm /downloads/russia.osm.pbf

FROM debian:bookworm-slim

COPY --from=builder /downloads /data
COPY --from=builder /osrm-bin/binding /osrm-bin

ENTRYPOINT ["/osrm-bin/osrm-routed", "--algorithm", "mld", "/data/russia.osrm"]