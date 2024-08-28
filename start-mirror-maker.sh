#!/bin/bash -e

KAFKA_VERSION=${1}
LOG_DIR=${2}

# Render config.
cp config-templates/mm2.properties rendered-config/${KAFKA_VERSION}/mm2.properties

# Setup log directory.
if [ ! -d "${LOG_DIR}" ]; then
    mkdir -p "${LOG_DIR}"
fi

# Configure logs.
export EXTRA_ARGS="-Dlog4j.configuration=file:../../mm2-log4j.properties -Dkafka.logs.dir=${LOG_DIR}"

cd installations/${KAFKA_VERSION}
nohup \
    bin/connect-mirror-maker.sh \
    $(realpath ../../rendered-config/${KAFKA_VERSION}/mm2.properties) \
    </dev/null >/dev/null 2>&1 &
