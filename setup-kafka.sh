#!/bin/bash -e

DEFAULT_KAFKA_VERSION=3.4.0
KAFKA_VERSION=${1:-${DEFAULT_KAFKA_VERSION}}

echo "Using Kafka ${KAFKA_VERSION}"
./download-and-unpack-kafka.sh ${KAFKA_VERSION}
