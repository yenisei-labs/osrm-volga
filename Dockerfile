# Public OSRM docker image is too old, apt is not working
FROM debian:bookworm-slim AS builder

# Установка необходимых пакетов и очистка кэша
RUN apt update && \
    apt install -y wget tar git osmium-tool && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Загрузка данных карты для Приволжья и Урала
WORKDIR /downloads
RUN wget http://download.geofabrik.de/russia/volga-fed-district-latest.osm.pbf -O volga.osm.pbf && \
    wget http://download.geofabrik.de/russia/ural-fed-district-latest.osm.pbf -O ural.osm.pbf

# Объединение двух регионов в один файл
RUN osmium merge volga.osm.pbf ural.osm.pbf -o volga_ural.osm.pbf && \
    rm volga.osm.pbf ural.osm.pbf

# Загрузка OSRM бинарников
WORKDIR /osrm-bin
RUN wget https://github.com/Project-OSRM/osrm-backend/releases/download/v5.27.1/node_osrm-v5.27.1-node-v108-linux-x64-Release.tar.gz -O osrm.tar.gz && \
    tar -xf osrm.tar.gz && \
    rm osrm.tar.gz

# Клонирование OSRM репозитория
RUN git clone --single-branch --branch v5.27.1 https://github.com/Project-OSRM/osrm-backend /osrm

# Обработка данных карты
WORKDIR /downloads
RUN /osrm-bin/binding/osrm-extract -p /osrm/profiles/car.lua /downloads/volga_ural.osm.pbf && \
    /osrm-bin/binding/osrm-partition volga_ural.osrm && \
    /osrm-bin/binding/osrm-customize volga_ural.osrm && \
    rm /downloads/volga_ural.osm.pbf

# Финальный образ
FROM debian:bookworm-slim

# Копирование необходимых файлов из builder stage
COPY --from=builder /downloads /data
COPY --from=builder /osrm-bin/binding /osrm-bin

# Запуск OSRM
ENTRYPOINT ["/osrm-bin/osrm-routed", "--algorithm", "mld", "/data/volga_ural.osrm"]