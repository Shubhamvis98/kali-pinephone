#!/bin/bash

ARCH='arm64'
qemu_bin='/usr/bin/qemu-aarch64-static'
machine='debian'
ENV='-E RUNLEVEL=1 -E LANG=C -E DEBIAN_FRONTEND=noninteractive -E DEBCONF_NOWARNINGS=yes'
LOOP=`losetup -f`
BOOT_P=${LOOP}p1
ROOT_P=${LOOP}p2
WORK_DIR=`dirname $0`
ROOTFS=${WORK_DIR}/kali_rootfs_tmp

banner()
{
cat <<'EOF'
-----------------------------------------
 _____     _   _____         _
|   | |___| |_|  |  |_ _ ___| |_ ___ ___
| | | | -_|  _|     | | |   |  _| -_|  _|
|_|___|___|_| |__|__|___|_|_|_| |___|_|
 _____
|  _  |___ ___
|   __|  _| . | Image Generator
|__|  |_| |___| by Shubham Vishwakarma

twitter/git: shubhamvis98
-----------------------------------------
EOF
}

nspawn-exec() {
    case "$1" in
        '-r')
            echo "$2" > ${ROOTFS}/__tmp.sh
            nspawn-exec bash /__tmp.sh
            rm ${ROOTFS}/__tmp.sh
            ;;
        *)
            systemd-nspawn --bind-ro $qemu_bin -M $machine --capability=cap_setfcap $ENV -D ${ROOTFS} "$@"
            ;;
    esac
}

mkimg() {
    set -e
    [[ -z $2 || $2 -lt 3 ]] && echo -e "Usage:\n\tmkimg {filename} {size_in_GB}\n\nNote: Size must be more than 3GB" && return
    IMG=$1
    SIZE=$2
    PARTS=$3
    [ -e ${IMG} ] && echo -e '[*]$IMG already exists. So, skipping mkimg' && return

    echo "[*]Creating blank Image: ${IMG} of size ${SIZE}GB..."
    dd if=/dev/zero of=${IMG} bs=1M count=$((1024*$SIZE)) status=progress

    source ./partuuid

    if [ $PARTS -eq 1 ]
    then
        losetup ${LOOP} ${IMG}
        mkfs.ext4 -L ROOT -U ${ROOT_UUID} ${LOOP}
        mkdir -pv ${ROOTFS}
        mount -v ${LOOP} ${ROOTFS}
    else
        echo '[*]Partitioning Image: 512MB BOOT and rest ROOTFS...'
        sleep 1
        cat << 'EOF' | sfdisk ${IMG}
        label: gpt
        device: test.img
        unit: sectors
        first-lba: 2048
        sector-size: 512
        1 : start=2048, size=1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
        2 : start=1050624, type=B921B045-1DF0-41C3-AF44-4C6F280D3FAE
EOF
        echo '[*]Formatting Partitions...'
        losetup ${LOOP} -P ${IMG}
        [ -e ${BOOT_P} ] && mkfs.ext4 -L BOOT -U ${BOOT_UUID} ${BOOT_P}
        [ -e ${ROOT_P} ] && mkfs.ext4 -L ROOT -U ${ROOT_UUID} ${ROOT_P}

        echo '[*]Mounting Partitions...'
        mkdir -pv ${ROOTFS}
        mount -v ${ROOT_P} ${ROOTFS}
        mkdir -pv ${ROOTFS}/boot
        mount -v ${BOOT_P} ${ROOTFS}/boot
    fi
}

cleanup() {
    set -x
    echo '[*]Unounting Partitions...'
    mountpoint -q ${ROOTFS}/boot && umount ${ROOTFS}/boot
    mountpoint -q ${ROOTFS} && umount ${ROOTFS}
    rm -rf ${ROOTFS} ./partuuid
    losetup -d ${LOOP}
}

trap ctrl_c INT
ctrl_c() {
    exit 1
}
