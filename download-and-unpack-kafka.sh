#!/bin/bash -e

KAFKA_VERSION=$1
# Some older versions of Kafka might not work as they use older Scala (might want to add 2nd param and link them if I ever want to use e.g. 1.1.1).
KAFKA_TARFILE="kafka_2.13-${KAFKA_VERSION}.tgz"
KAFKA_REMOTE="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/${KAFKA_TARFILE}"

KAFKA_LOCAL_TARFILE="tgz/${KAFKA_TARFILE}"

if [ ! -f "${KAFKA_LOCAL_TARFILE}" ]; then
	wget "${KAFKA_REMOTE}" -P tgz
fi

KAFKA_INSTALL_DIR="installations/${KAFKA_VERSION}"

if [ ! -f "${KAFKA_INSTALL_DIR}" ]; then
	echo "Setting up directory ${KAFKA_INSTALL_DIR}"
	mkdir -p "${KAFKA_INSTALL_DIR}"
	echo "Extracting"
	tar -xzf "${KAFKA_LOCAL_TARFILE}" -C "${KAFKA_INSTALL_DIR}" --strip-components=1
fi
