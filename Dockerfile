# Public OSRM docker image is too old, apt is not working
FROM debian:bookworm-slim AS builder

RUN apt update

# Download map data
RUN apt install -y wget
WORKDIR /downloads
RUN wget https://download.geofabrik.de/russia/volga-fed-district-latest.osm.pbf -O volga.osm.pbf
RUN wget https://download.geofabrik.de/russia/ural-fed-district-latest.osm.pbf -O ural.osm.pbf

RUN wget -O - http://m.m.i24.cc/osmconvert.c | cc -x c - -lz -O3 -o osmconvert
RUN ./osmconvert volga.osm.pbf --out-o5m | ./osmconvert - ural.osm.pbf -o=ural-volga.pbf

# Download OSRM binaries
WORKDIR /osrm-bin
RUN wget https://github.com/Project-OSRM/osrm-backend/releases/download/v5.27.1/node_osrm-v5.27.1-node-v108-linux-x64-Release.tar.gz -O osrm.tar.gz
RUN apt install -y tar
RUN tar -xf osrm.tar.gz

# Clone OSRM repository
RUN apt install -y git
RUN git clone --single-branch --branch v5.27.1 https://github.com/Project-OSRM/osrm-backend /osrm

WORKDIR /downloads
RUN /osrm-bin/binding/osrm-extract -p /osrm/profiles/car.lua /downloads/ural-volga.pbf
RUN /osrm-bin/binding/osrm-partition ural-volga.osrm
RUN /osrm-bin/binding/osrm-customize ural-volga.osrm
RUN rm /downloads/ural-volga.pbf

FROM debian:bookworm-slim

COPY --from=builder /downloads /data
COPY --from=builder /osrm-bin/binding /osrm-bin

ENTRYPOINT ["/osrm-bin/osrm-routed", "--algorithm", "mld", "/data/ural-volga.osrm"]
