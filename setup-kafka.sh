#!/bin/bash -e

DEFAULT_KAFKA_VERSION=3.5.1
KAFKA_VERSION=${1:-${DEFAULT_KAFKA_VERSION}}

echo "Using Kafka ${KAFKA_VERSION}"
./download-and-unpack-kafka.sh ${KAFKA_VERSION}

CONFIG_DIR="rendered-config/${KAFKA_VERSION}"
mkdir -p "${CONFIG_DIR}" || true

DATA_DIR="/tmp/kafka-data"
if [ ! -f "${DATA_DIR}" ]; then
    mkdir -p "${DATA_DIR}"
fi

LOG_DIR="/tmp/kafka-logs"
if [ ! -f "${LOG_DIR}" ]; then
    mkdir -p "${LOG_DIR}"
fi

TYPES=(default envoy mesh mirror)
COUNTS=(3 1 3 1)

for idx in ${!TYPES[@]}; do
    TYPE=${TYPES[$idx]}
    COUNT=${COUNTS[$idx]}
    for id in $(seq ${COUNT}); do
        echo "Starting server ${TYPE}/${id}"
        ./start-kafka-server.sh \
            "${KAFKA_VERSION}" \
            "${CONFIG_DIR}" \
            "${id}" \
            "${TYPE}" \
            "${DATA_DIR}" \
            "${LOG_DIR}"
    done
done
