#!/bin/bash -e

DEFAULT_KAFKA_VERSION=3.7.0
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

TYPE=${2:-"all"}
case ${TYPE} in
    "default")
        TYPES=("default:3")
        ;;
    "envoy")
        TYPES=("envoy:1")
        ;;
    "mesh")
        TYPES=("mesh:3")
        ;;
    "mirror")
        TYPES=("mirror:1")
        ;;
    "all")
        TYPES=("default:3" "envoy:1" "mesh:3" "mirror:1")
        ;;
    "*")
        TYPES=("default:3" "envoy:1" "mesh:3" "mirror:1")
        ;;
esac

echo "Starting: "
for el in "${TYPES[@]}" ; do
    echo -n "${el} "
done
echo

for el in ${TYPES[@]}; do
    TYPE=${el%%:*}
    COUNT=${el#*:}
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
