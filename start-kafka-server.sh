#!/bin/bash -e

if [ $# -lt 6 ]; then
	echo "Illegal number of parameters, need VERSION TARGET_DIR ID TYPE DATA_DIR_PARENT LOG_DIR"
	exit 1
fi

VERSION=$1
TARGET_DIR=$2
ID=$3
TYPE=${4}
DATA_DIR_PARENT=${5}
LOG_DIR=${6}

echo "Starting server ${VERSION} ${TARGET_DIR} ${ID} ${TYPE} ${DATA_DIR_PARENT} ${LOG_DIR}"

# Port offsets.
OFFSET=0
if [ "envoy" == ${TYPE} ]; then
    OFFSET=200
fi
if [ "mesh" == ${TYPE} ]; then
    OFFSET=400
fi

# Kafka listener port.
KAFKA_PORT=$((9091 + ${OFFSET} + ${ID}))

# Kafka advertised listener port.
if [ "envoy" == ${TYPE} ]; then
	ADV_PORT=$((10000 + 9091 + ${ID}))
else
	ADV_PORT=${KAFKA_PORT}
fi

# Kafka data directory.
DATA_DIR="${DATA_DIR_PARENT}/${TYPE}-${ID}"

# Render the config.
sed \
	-e "s/__ID__/${ID}/g" \
	-e "s/__PORT__/${KAFKA_PORT}/g" \
	-e "s/__ADV_PORT__/${ADV_PORT}/g" \
	-e "s+__DATA_DIR__+${DATA_DIR}+g" \
	config-templates/server-${TYPE}-0.properties.template > "${TARGET_DIR}/server-${TYPE}-${ID}.properties"
echo "Listening on port ${KAFKA_PORT}, advertised on ${ADV_PORT}"

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

# Configure logs.
export EXTRA_ARGS="-Dlog4j.configuration=file:../../log4j.properties -Dkafka.logs.dir=${LOG_DIR} -Dlogsuffix=${TYPE}-${ID}"

cd installations/${VERSION}
nohup \
    bin/kafka-server-start.sh \
    ../../rendered-config/${VERSION}/server-${TYPE}-${ID}.properties \
    </dev/null >/dev/null 2>&1 &
