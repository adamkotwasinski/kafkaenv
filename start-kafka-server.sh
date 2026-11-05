#!/bin/bash -e

# Renders the config for a single Kafka server and starts it in the background.
#
# Usage: ./start-kafka-server.sh KAFKA_VERSION CONFIG_TARGET_DIR ID TYPE DATA_DIR_PARENT LOG_DIR CLUSTER_SIZE
#
# KAFKA_VERSION
#   Version to start, taken from installations/<KAFKA_VERSION>. Major version selects ZooKeeper (below 4) or KRaft (4 and above) configuration.
# CONFIG_TARGET_DIR
#   Directory the rendered config (server-<TYPE>-<ID>.properties) is written to, e.g. rendered-config/4.4.0.
# ID
#   1-based index of the server within its type. Determines ports, data directory and log file names
#   (and the node id, except for 'mesh').
# TYPE
#   Server type: default, envoy, mesh or mirror. Determines the port offset (0, 200, 400, 600 respectively)
#   and, for Kafka below 4, the config template used.
# DATA_DIR_PARENT
#   Parent of the data directories; the server uses <DATA_DIR_PARENT>/<TYPE>-<ID>, which is wiped on every start.
# LOG_DIR
#   Directory for log files (*-<TYPE>-<ID>.log); old logs of this server are removed on start.
# CLUSTER_SIZE
#   Number of servers in the cluster this server belongs to, used to build controller.quorum.voters (KRaft only).
#   Ignored for 'mesh' (every server is its own single-node cluster) and for Kafka below 4.
#
# Ports (offset depends on TYPE):
#   Kafka listener     - 9091 + offset + ID (advertised the same, except 'envoy': 10000 + 9091 + ID)
#   Controller (KRaft) - 29091 + offset + ID
#   JMX                - 18000 + offset + ID
#   MX4J               - 8081 + offset + ID

if [ $# -lt 7 ]; then
    echo "Illegal number of parameters, need KAFKA_VERSION CONFIG_TARGET_DIR ID TYPE DATA_DIR_PARENT LOG_DIR CLUSTER_SIZE"
    exit 1
fi

KAFKA_VERSION=${1}
CONFIG_TARGET_DIR=${2}
ID=${3}
TYPE=${4}
DATA_DIR_PARENT=${5}
LOG_DIR=${6}
CLUSTER_SIZE=${7}

echo "Starting server ${KAFKA_VERSION} ${CONFIG_TARGET_DIR} ${ID} ${TYPE} ${DATA_DIR_PARENT} ${LOG_DIR} ${CLUSTER_SIZE}"

# Kafka 4.0 removed ZooKeeper mode, so these versions need KRaft configuration.
KAFKA_MAJOR_VERSION=${KAFKA_VERSION%%.*}

# Port offsets.
OFFSET=0
if [ "envoy" == ${TYPE} ]; then
    OFFSET=200
fi
if [ "mesh" == ${TYPE} ]; then
    OFFSET=400
fi
if [ "mirror" == ${TYPE} ]; then
    OFFSET=600
fi

# Kafka listener port.
KAFKA_PORT=$((9091 + ${OFFSET} + ${ID}))

# Kafka controller listener port (KRaft only).
CONTROLLER_PORT=$((29091 + ${OFFSET} + ${ID}))

# Kafka advertised listener port.
if [ "envoy" == ${TYPE} ]; then
    ADV_PORT=$((10000 + 9091 + ${ID}))
else
    ADV_PORT=${KAFKA_PORT}
fi

# Log4j2 configuration (absolute, as we change directory later).
LOG4J_CONFIG=$(realpath log4j2.yaml)

# Kafka data directory.
DATA_DIR="${DATA_DIR_PARENT}/${TYPE}-${ID}"

# Render the config.
if [ "${KAFKA_MAJOR_VERSION}" -ge 4 ]; then
    if [ "mesh" == ${TYPE} ]; then
        # Every mesh server is a separate single-node cluster.
        CLUSTER_NAME="${TYPE}-${ID}"
        NODE_ID=1
        QUORUM_VOTERS="1@127.0.0.1:${CONTROLLER_PORT}"
    else
        CLUSTER_NAME="${TYPE}"
        NODE_ID=${ID}
        QUORUM_VOTERS=""
        for member in $(seq ${CLUSTER_SIZE}); do
            QUORUM_VOTERS+="${QUORUM_VOTERS:+,}${member}@127.0.0.1:$((29091 + ${OFFSET} + ${member}))"
        done
    fi
    # Stable cluster id, so all the servers of one cluster agree on it.
    CLUSTER_ID=$(printf '%s' "kafkaenv-${CLUSTER_NAME}" | openssl dgst -md5 -binary | base64 | tr '+/' '-_' | tr -d '=')

    sed \
        -e "s/__NODE_ID__/${NODE_ID}/g" \
        -e "s/__QUORUM_VOTERS__/${QUORUM_VOTERS}/g" \
        -e "s/__PORT__/${KAFKA_PORT}/g" \
        -e "s/__CONTROLLER_PORT__/${CONTROLLER_PORT}/g" \
        -e "s/__ADV_PORT__/${ADV_PORT}/g" \
        -e "s+__DATA_DIR__+${DATA_DIR}+g" \
        config-templates/server-kraft.properties.template > "${CONFIG_TARGET_DIR}/server-${TYPE}-${ID}.properties"
    echo "Listening on port ${KAFKA_PORT}, advertised on ${ADV_PORT}, controller on ${CONTROLLER_PORT} (cluster ${CLUSTER_NAME}/${CLUSTER_ID}, voters ${QUORUM_VOTERS})"
else
    sed \
        -e "s/__ID__/${ID}/g" \
        -e "s/__PORT__/${KAFKA_PORT}/g" \
        -e "s/__ADV_PORT__/${ADV_PORT}/g" \
        -e "s+__DATA_DIR__+${DATA_DIR}+g" \
        config-templates/server-${TYPE}-0.properties.template > "${CONFIG_TARGET_DIR}/server-${TYPE}-${ID}.properties"
    echo "Listening on port ${KAFKA_PORT}, advertised on ${ADV_PORT}"
fi

# JMX port.
export JMX_PORT=$((18000 + ${OFFSET} + ${ID}))
export KAFKA_JMX_OPTS="-Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.local.only=false"
echo "JMX enabled on ${JMX_PORT}"

# MX4J port.
MX4J_PORT=$((8081 + ${OFFSET} + ${ID}))
export KAFKA_HEAP_OPTS="-Xmx512M -Dkafka_mx4jenable=true -Dmx4jport=${MX4J_PORT}"
echo "MX4J enabled on port ${MX4J_PORT}"

# Cleanup old data "quickly".
if [ -d "${DATA_DIR}" ]; then
    TDIR=$(mktemp -d)
    mv "${DATA_DIR}/" "${TDIR}"
    rm -rf "${TDIR}" &
fi

# Setup data directory.
if [ ! -d "${DATA_DIR}" ]; then
    mkdir -p "${DATA_DIR}"
fi

# Cleanup old logs.
rm -rfv ${LOG_DIR}/*-${TYPE}-${ID}.log || true

# Setup log directory.
if [ ! -d "${LOG_DIR}" ]; then
    mkdir -p "${LOG_DIR}"
fi

cd installations/${KAFKA_VERSION}
SERVER_CONFIG=$(realpath ../../rendered-config/${KAFKA_VERSION}/server-${TYPE}-${ID}.properties)

if [ "${KAFKA_MAJOR_VERSION}" -ge 4 ]; then
    # Configure logs (log4j2).
    export LOG_DIR
    export KAFKA_LOG4J_OPTS="-Dlog4j2.configurationFile=${LOG4J_CONFIG} -Dlogsuffix=${TYPE}-${ID}"
    export EXTRA_ARGS=""

    # Format the (freshly cleaned) data directory; the tool should not grab the server's JMX port.
    env -u JMX_PORT -u KAFKA_JMX_OPTS -u KAFKA_HEAP_OPTS \
        bin/kafka-storage.sh format --cluster-id="${CLUSTER_ID}" --config "${SERVER_CONFIG}" --ignore-formatted >/dev/null
else
    # Configure logs (log4j).
    export EXTRA_ARGS="-Dlog4j.configuration=file:../../log4j.properties -Dkafka.logs.dir=${LOG_DIR} -Dlogsuffix=${TYPE}-${ID}"
fi

nohup \
    bin/kafka-server-start.sh \
    "${SERVER_CONFIG}" \
    </dev/null >/dev/null 2>&1 &
