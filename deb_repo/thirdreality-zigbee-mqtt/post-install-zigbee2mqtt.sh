#!/bin/bash

#libcjson1_1.7.15-1+deb12u2_arm64.deb  
#libdlt2_2.18.8-6_arm64.deb 
#libmosquitto1_2.0.11-1.2+deb12u1_arm64.deb  
#mosquitto-clients_2.0.11-1.2+deb12u1_arm64.deb
#mosquitto_2.0.11-1.2+deb12u1_arm64.deb

#libsystemd-dev_252.36-1~deb12u1_arm64.deb
#nodejs_22.16.0-1nodesource1_arm64.deb

DEFAULT_ARCH="/var/cache/apt/archives"

if [ -d "/usr/lib/thirdreality/archives" ]; then
    rm -rf ${DEFAULT_ARCH}/*.deb

    cp /usr/lib/thirdreality/archives/*.deb ${DEFAULT_ARCH}

    dpkg -i ${DEFAULT_ARCH}/libcjson1_*.deb > /dev/null || true
    dpkg -i ${DEFAULT_ARCH}/libdlt2_*.deb > /dev/null || true
    dpkg -i ${DEFAULT_ARCH}/libmosquitto1_*.deb > /dev/null || true
    dpkg -i ${DEFAULT_ARCH}/mosquitto-clients_*.deb > /dev/null || true
    dpkg -i ${DEFAULT_ARCH}/mosquitto_*.deb > /dev/null || true

    dpkg -i ${DEFAULT_ARCH}/libsystemd-dev_*.deb > /dev/null || true
    dpkg -i ${DEFAULT_ARCH}/nodejs_*.deb > /dev/null || true
    
    apt-get install -f > /dev/null || true

    rm -rf ${DEFAULT_ARCH}/*.deb
fi

exit 0


