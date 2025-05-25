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

# #TODO 检查：如果mosquitto-clients, 以及mosquitto没有安装， 则进行如下操作
# apt update
# apt install -y mosquitto mosquitto-clients
# systemctl enable mosquitto.service
# systemctl disable mosquitto.service
# mosquitto -v

# #post install
# mosquitto_passwd -c /etc/mosquitto/passwd thirdreality thirdreality
# cp ${current_dir}/mosquitto.conf /etc/mosquitto/mosquitto.conf

# systemctl start mosquitto.service


# curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
# apt-get install -y nodejs git make g++ gcc libsystemd-dev

if [ ! -d "/lib/node_modules/pnpm" ]; then
    npm install -g pnpm
if

node --version # Should output V18.x, V20.x, V21.X
npm --version # Should output 9.X or 10.X

if [ ! -d "/opt/zigbee2mqtt" ]; then
    mkdir /opt/zigbee2mqtt
    git clone --depth 1 https://github.com/Koenkk/zigbee2mqtt.git /opt/zigbee2mqtt
    cd /opt/zigbee2mqtt
    npm ci
    npm run build
fi

# cp ${current_dir}/configuration.yaml /opt/zigbee2mqtt/data/configuration.yaml

# 创建软件
print_info "Create output directory ..."
mkdir -p "${output_dir}"

print_info "syncing DEBIAN ..."
rm -rf ${output_dir}/DEBIAN > /dev/null 2>&1
cp ${current_dir}/DEBIAN ${output_dir}/ -R

mkdir -p ${output_dir}/var/cache/apt/archives
mkdir -p ${output_dir}/lib/node_modules/pnpm
mkdir -p ${output_dir}/opt/zigbee2mqtt
mkdir -p ${output_dir}/etc/systemd/system

cp ${current_dir}/deb/mosquitto/*.deb ${output_dir}/var/cache/apt/archives/ -R
cp ${current_dir}/deb/nodejs/*.deb ${output_dir}/var/cache/apt/archives/ -R

cp /lib/node_modules/pnpm ${output_dir}/lib/node_modules/ -R
cp /opt/zigbee2mqtt ${output_dir}/opt/ -R

cp /etc/systemd/system/zigbee2mqtt.service ${output_dir}/etc/systemd/system/zigbee2mqtt.service

# ---------------------

print_info "Start to build zigbee-mqtt_${version}.deb ..."
dpkg-deb --build ${output_dir} ${current_dir}/zigbee-mqtt_${version}.deb

rm -rf ${output_dir}/usr > /dev/null 2>&1
rm -rf ${output_dir}/etc > /dev/null 2>&1

print_info "Build zigbee-mqtt_${version}.deb finished ..."



