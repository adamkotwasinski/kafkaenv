#!/bin/bash -e

# Starts local Kafka clusters (downloading the Kafka distribution if needed).
#
# Usage: ./setup-kafka.sh [KAFKA_VERSION] [TYPE]
#
# KAFKA_VERSION (optional, default: DEFAULT_KAFKA_VERSION below)
#   Kafka version to start, e.g. 3.8.0. Versions below 4 use ZooKeeper, 4 and above use KRaft.
# TYPE (optional, default: all)
#   Which clusters to start ('type:N' means N servers of that type):
#     basic       - default:3
#     envoy       - envoy:1
#     mesh        - mesh:3 (3 independent single-node clusters)
#     mirror      - default:3, mirror:1, and mirror-maker (Kafka 3.x only)
#     twoclusters - default:3, mirror:1, without mirror-maker
#     all         - default:3, envoy:1, mesh:3, mirror:1, and mirror-maker (Kafka 3.x only)

DEFAULT_KAFKA_VERSION=4.4.0
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
START_MIRROR_MAKER="false"
case ${TYPE} in
    "basic")
        TYPES=("default:3")
        ;;
    "envoy")
        TYPES=("envoy:1")
        ;;
    "mesh")
        TYPES=("mesh:3")
        ;;
    "mirror")
        TYPES=("default:3 mirror:1")
        START_MIRROR_MAKER="true"
        ;;
    "twoclusters")
        TYPES=("default:3 mirror:1")
        ;;
    "all")
        TYPES=("default:3" "envoy:1" "mesh:3" "mirror:1")
        START_MIRROR_MAKER="true"
        ;;
    "*")
        TYPES=("default:3" "mirror:1")
        ;;
esac

echo "=== STARTING CLUSTERS: ${TYPES[*]} ==="

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
            "${LOG_DIR}" \
            "${COUNT}"
    done
done

if [[ "${START_MIRROR_MAKER}" == "true" ]]; then
    echo "Starting mirror-maker"
    ./start-mirror-maker.sh \
        "${KAFKA_VERSION}" \
        "${LOG_DIR}"
fi
