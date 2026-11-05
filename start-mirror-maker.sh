#!/bin/bash -e

# Starts mirror-maker in the background. Does nothing for Kafka 4 and above, where it is not supported.
#
# Usage: ./start-mirror-maker.sh KAFKA_VERSION LOG_DIR
#
# KAFKA_VERSION
#   Version to use, taken from installations/<KAFKA_VERSION>.
# LOG_DIR
#   Directory for the mirror-maker log (mm2.log).

KAFKA_VERSION=${1}
LOG_DIR=${2}

# Mirror-maker is not supported with Kafka 4.0+ (KRaft-only setup), so skip it.
KAFKA_MAJOR_VERSION=${KAFKA_VERSION%%.*}
if [ "${KAFKA_MAJOR_VERSION}" -ge 4 ]; then
    echo "Mirror-maker is not supported for Kafka ${KAFKA_VERSION}, not starting it"
    exit 0
fi

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
