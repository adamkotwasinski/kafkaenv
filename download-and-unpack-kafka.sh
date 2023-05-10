#!/bin/bash -e

KAFKA_VERSION=$1
# Some older versions of Kafka might not work as they use older Scala (might want to add 2nd param and link them if I ever want to use e.g. 1.1.1).
KAFKA_TARFILE="kafka_2.13-${KAFKA_VERSION}.tgz"
KAFKA_REMOTE="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/${KAFKA_TARFILE}"

KAFKA_LOCAL_TARFILE="tgz/${KAFKA_TARFILE}"

if [ ! -f "${KAFKA_LOCAL_TARFILE}" ]; then
    echo "Downloading ${KAFKA_LOCAL_TARFILE}"
    wget "${KAFKA_REMOTE}" -P tgz
fi

MX4J_VERSION=3.0.1
MX4J_FILE="mx4j-tools-${MX4J_VERSION}.jar"
MX4J_LOCAL_FILE="tgz/${MX4J_FILE}"
if [ ! -f "${MX4J_LOCAL_FILE}" ]; then
    echo "Downloading ${MX4J_FILE}"
    MX4J_REMOTE="https://repo1.maven.org/maven2/mx4j/mx4j-tools/${MX4J_VERSION}/${MX4J_FILE}"
    wget "${MX4J_REMOTE}" -P tgz
fi

KAFKA_INSTALL_DIR="installations/${KAFKA_VERSION}"

if [ ! -f "${KAFKA_INSTALL_DIR}" ]; then
    echo "Setting Kafka installation in ${KAFKA_INSTALL_DIR}"
    mkdir -p "${KAFKA_INSTALL_DIR}"
    tar -xzf "${KAFKA_LOCAL_TARFILE}" -C "${KAFKA_INSTALL_DIR}" --strip-components=1
    cp "${MX4J_LOCAL_FILE}" "${KAFKA_INSTALL_DIR}/libs"
fi
