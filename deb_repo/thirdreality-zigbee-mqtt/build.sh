#!/bin/bash

current_dir=$(pwd)
output_dir="${current_dir}/output"

REBUILD=false
CLEAN=false


SCRIPT="ThirdReality"
print_info() { echo -e "\e[1;34m[${SCRIPT}] INFO:\e[0m $1"; }
print_error() { echo -e "\e[1;31m[${SCRIPT}] ERROR:\e[0m $1"; }

print_info "Usage: Build.sh [--rebuild] [--clean]"
print_info "Options:"
print_info "  --rebuild: Rebuild the env"
print_info "  --clean: Clean the output directory and remove the env"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --rebuild) REBUILD=true ;;
        --clean) CLEAN=true ;;
        *) print_error "未知参数: $1" >&2; exit 1 ;;
    esac
    shift
done

version=$(grep '^Version:' ${current_dir}/DEBIAN/control | awk '{print $2}')
print_info "Version: $version"


#清场
if [[ "$CLEAN" == true ]]; then
    rm -rf "${output_dir}" > /dev/null 2>&1
    rm -rf ${current_dir}/*.deb > /dev/null 2>&1

    exit 0
fi

#半清场
if [[ "$REBUILD" == true ]]; then
    print_info "zigbee-mqtt_${version}.deb rebuilding ..."
    rm -rf "${output_dir}" > /dev/null 2>&1

fi

mkdir -p "${output_dir}"
cp ${current_dir}/DEBIAN ${output_dir}/ -R

# 安装软件

# 检查：如果mosquitto-clients, 以及mosquitto没有安装， 则进行如下操作
if ! dpkg -l | grep -q "mosquitto " || ! dpkg -l | grep -q "mosquitto-clients"; then
    print_info "Installing mosquitto and mosquitto-clients..."
    apt update
    apt install -y mosquitto mosquitto-clients
    systemctl enable mosquitto.service
    systemctl disable mosquitto.service
    mosquitto -v
fi

# post install
if [ -f "/usr/bin/mosquitto_passwd" ]; then 
	rm -rf /etc/mosquitto/passwd
	mosquitto_passwd -b -c /etc/mosquitto/passwd thirdreality thirdreality
fi
cp ${current_dir}/mosquitto.conf /etc/mosquitto/mosquitto.conf

systemctl start mosquitto.service

if ! dpkg -l | grep -q "nodejs "; then
    print_info "Installing nodejs..."
    #curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    apt install -y nodejs libsystemd-dev   
fi

if [ ! -d "/lib/node_modules/pnpm" ]; then
    npm install -g pnpm
fi

node --version # Should output V18.x, V20.x, V21.X
npm --version # Should output 9.X or 10.X

if [ ! -d "/opt/zigbee2mqtt" ]; then
    mkdir /opt/zigbee2mqtt
    git clone --depth 1 https://github.com/Koenkk/zigbee2mqtt.git /opt/zigbee2mqtt
    cd /opt/zigbee2mqtt
    npm ci
    cp ${current_dir}/configuration.yaml /opt/zigbee2mqtt/data/configuration.yaml
    npm run build
fi


# 创建软件
print_info "Create output directory ..."
mkdir -p "${output_dir}"

print_info "syncing DEBIAN ..."
rm -rf ${output_dir}/DEBIAN > /dev/null 2>&1
cp ${current_dir}/DEBIAN ${output_dir}/ -R

print_info "Backup mosquitto ..."

mkdir -p ${output_dir}/usr/lib/aarch64-linux-gnu/
cp /usr/lib/aarch64-linux-gnu/libcjson.so.1.7.15 ${output_dir}/usr/lib/aarch64-linux-gnu/
cp /usr/lib/aarch64-linux-gnu/libdlt.so.2.18.8 ${output_dir}/usr/lib/aarch64-linux-gnu/
cp /usr/lib/aarch64-linux-gnu/libmosquitto.so.2.0.11 ${output_dir}/usr/lib/aarch64-linux-gnu/
cp /usr/lib/aarch64-linux-gnu/mosquitto_dynamic_security.so ${output_dir}/usr/lib/aarch64-linux-gnu/

mkdir -p ${output_dir}/usr/bin/
cp /usr/bin/mosquitto_ctrl ${output_dir}/usr/bin/
cp /usr/bin/mosquitto_passwd ${output_dir}/usr/bin/
cp /usr/bin/mosquitto_pub ${output_dir}/usr/bin/
cp /usr/bin/mosquitto_rr ${output_dir}/usr/bin/
cp /usr/bin/mosquitto_sub ${output_dir}/usr/bin/

mkdir -p ${output_dir}/usr/sbin/
cp /usr/sbin/mosquitto  ${output_dir}/usr/sbin/

mkdir -p ${output_dir}/etc/mosquitto
cp /etc/mosquitto ${output_dir}/etc/ -R

mkdir -p ${output_dir}/etc/init.d/
cp /etc/init.d/mosquitto ${output_dir}/etc/init.d/

mkdir -p ${output_dir}/etc/logrotate.d/
cp /etc/logrotate.d/mosquitto  ${output_dir}/etc/logrotate.d/

mkdir -p ${output_dir}/usr/share/lintian/overrides/
cp /usr/share/lintian/overrides/mosquitto-clients ${output_dir}/usr/share/lintian/overrides/

mkdir -p ${output_dir}/lib/systemd/system
cp /lib/systemd/system/mosquitto.service ${output_dir}/lib/systemd/system/mosquitto.service

print_info "Backup nodejs ..."

#libsystemd-dev_252.36-1~deb12u1_arm64.deb
mkdir -p ${output_dir}/usr/include/systemd/
cp /usr/include/systemd ${output_dir}/usr/include/ -R

mkdir -p ${output_dir}/usr/lib/aarch64-linux-gnu/pkgconfig
cp /usr/lib/aarch64-linux-gnu/pkgconfig/libsystemd.pc ${output_dir}/usr/lib/aarch64-linux-gnu/pkgconfig/

mkdir -p ${output_dir}/usr/include/node/
cp /usr/bin/node ${output_dir}/usr/bin/
cp /usr/include/node/  ${output_dir}/usr/include/ -R

mkdir -p ${output_dir}/opt/zigbee2mqtt
cp /opt/zigbee2mqtt ${output_dir}/opt/ -R


mkdir -p ${output_dir}/lib/node_modules
cp /lib/node_modules/corepack ${output_dir}/lib/node_modules/ -R
cp /lib/node_modules/npm ${output_dir}/lib/node_modules/ -R
cp /lib/node_modules/pnpm ${output_dir}/lib/node_modules/ -R

mkdir -p ${output_dir}/etc/systemd/system/
cp /etc/systemd/system/zigbee2mqtt.service ${output_dir}/etc/systemd/system/zigbee2mqtt.service

#
print_info "backup default config files..."
cp ${current_dir}/configuration.yaml ${output_dir}/opt/zigbee2mqtt/data/configuration.yaml.default
cp ${current_dir}/mosquitto.conf ${output_dir}/etc/mosquitto/mosquitto.conf.default

# ---------------------

print_info "Start to build zigbee-mqtt_${version}.deb ..."
dpkg-deb --build ${output_dir} ${current_dir}/zigbee-mqtt_${version}.deb

rm -rf ${output_dir}/usr > /dev/null 2>&1
rm -rf ${output_dir}/etc > /dev/null 2>&1

print_info "Build zigbee-mqtt_${version}.deb finished ..."
