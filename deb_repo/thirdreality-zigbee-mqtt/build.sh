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

if [[ "$CLEAN" == true ]]; then
    rm -rf "${output_dir}" > /dev/null 2>&1
    rm -rf ${current_dir}/*.deb > /dev/null 2>&1

    exit 0
fi

if [[ "$REBUILD" == true ]]; then
    print_info "zigbee_mqtt_${version}.deb rebuilding ..."
    rm -rf "${output_dir}" > /dev/null 2>&1
    mkdir -p "${output_dir}"

    cp ${current_dir}/DEBIAN ${output_dir}/ -R
fi

print_info "Create output directory ..."
mkdir -p "${output_dir}"

print_info "syncing DEBIAN ..."
rm -rf ${output_dir}/DEBIAN > /dev/null 2>&1
cp ${current_dir}/DEBIAN ${output_dir}/ -R

mkdir -p ${output_dir}/etc/default/
mkdir -p ${output_dir}/etc/init.d/
mkdir -p ${output_dir}/etc/dbus-1/system.d/
mkdir -p ${output_dir}/etc/sysctl.d/

mkdir -p ${output_dir}/usr/sbin/
mkdir -p ${output_dir}/usr/bin/
mkdir -p ${output_dir}/usr/lib/systemd/system/
mkdir -p ${output_dir}/usr/lib/thirdreality/
mkdir -p ${output_dir}/usr/include/

# ---------------------

print_info "Start to build zigbee_mqtt_${version}.deb ..."
dpkg-deb --build ${output_dir} ${current_dir}/zigbee_mqtt_${version}.deb

rm -rf ${output_dir}/usr > /dev/null 2>&1
rm -rf ${output_dir}/etc > /dev/null 2>&1

print_info "Build zigbee_mqtt_${version}.deb finished ..."



