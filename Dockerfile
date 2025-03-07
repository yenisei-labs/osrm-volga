FROM debian:bookworm-slim AS builder

RUN apt update && apt install -y --no-install-recommends wget tar git osmosis

# Download Volga region
RUN wget https://download.geofabrik.de/russia/volga-fed-district-latest.osm.pbf -O volga.osm.pbf

# Download Ural region
RUN wget https://download.geofabrik.de/russia/ural-fed-district-latest.osm.pbf -O ural.osm.pbf

# Combine Volga and Ural data
RUN osmosis --rx volga.osm.pbf --rx ural.osm.pbf --merge --wx russia-small.osm.pbf

# Download OSRM binaries
WORKDIR /osrm-bin
RUN wget https://github.com/Project-OSRM/osrm-backend/releases/download/v5.27.1/node_osrm-v5.27.1-node-v108-linux-x64-Release.tar.gz -O osrm.tar.gz
RUN tar -xf osrm.tar.gz

# Clone OSRM repository
RUN git clone --single-branch --branch v5.27.1 https://github.com/Project-OSRM/osrm-backend /osrm

WORKDIR /downloads
RUN /osrm-bin/binding/osrm-extract -p /osrm/profiles/car.lua /downloads/russia-small.osm.pbf
RUN /osrm-bin/binding/osrm-partition russia-small.osrm
RUN /osrm-bin/binding/osrm-customize russia-small.osrm
RUN rm /downloads/russia-small.osm.pbf

FROM debian:bookworm-slim

COPY --from=builder /downloads /data
COPY --from=builder /osrm-bin/binding /osrm-bin

ENTRYPOINT ["/osrm-bin/osrm-routed", "--algorithm", "mld", "/data/russia-small.osrm"]