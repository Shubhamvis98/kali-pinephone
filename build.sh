#!/bin/bash

. ./funcs.sh

device="pinephone"
environment="phosh"
hostname="fossfrog"
username="kali"
password="8888"
mobian_suite="bookworm"
family=
ARGS=
compress=
blockmap=
IMGSIZE=5   # GBs

while getopts "cbt:e:h:u:p:s:m:" opt
do
    case "$opt" in
        t ) device="$OPTARG" ;;
        e ) environment="$OPTARG" ;;
        h ) hostname="$OPTARG" ;;
        u ) username="$OPTARG" ;;
        p ) password="$OPTARG" ;;
        s ) custom_script="$OPTARG" ;;
        m ) mobian_suite="$OPTARG" ;;
        c ) compress=1 ;;
        b ) blockmap=1 ;;
    esac
done

case "$device" in
  "pinephone" )
    arch="arm64"
    family="sunxi"
    services="eg25-manager"
    ;;
  "pinephonepro" )
    arch="arm64"
    family="rockchip"
    services="eg25-manager"
    ;;
  "sdm845" )
    arch="arm64"
    family="sdm845"
    services="qrtr-ns rmtfs pd-mapper tqftpserv qcom-modem-setup droid-juicer"
    PARTITIONS=1
    SPARSE=1
    ;;
  * )
    echo "Unsupported device ${device}"
    exit 1
    ;;
esac

PACKAGES="kali-linux-core ${device}-support wget curl rsync systemd-timesyncd"
case "${environment}" in
    phosh)
        PACKAGES="${PACKAGES} phosh-phone phog portfolio-filemanager"
        services="${services} greetd"
        ;;
    xfce|lxde|gnome|kde) PACKAGES="${PACKAGES} kali-desktop-${environment}" ;;
esac

IMG="kali_${environment}_${device}_`date +%Y%m%d`.img"
ROOTFS_TAR="kali_${environment}_${device}_`date +%Y%m%d`.tgz"
ROOTFS="kali_rootfs_tmp"

### START BUILDING ###
banner
echo '____________________BUILD_INFO____________________'
echo "Device: $device"
echo "Environment: $environment"
echo "Hostname: $hostname"
echo "Username: $username"
echo "Password: $password"
echo "Mobian Suite: $mobian_suite"
echo "Family: $family"
echo "Custom Script: $custom_script"
echo -e '--------------------------------------------------\n\n'
echo '[*]Build will start in 5 seconds...'; sleep 5

echo '[+]Stage 1: Debootstrap'
[ -e ${ROOTFS}/etc ] && echo -e "[*]Debootstrap already done.\nSkipping Debootstrap..." || debootstrap --foreign --arch $arch kali-rolling ${ROOTFS} http://kali.download/kali

echo '[+]Stage 2: Debootstrap second stage and adding Mobian apt repo'
[ -e ${ROOTFS}/etc/passwd ] && echo '[*]Second Stage already done' || nspawn-exec /debootstrap/debootstrap --second-stage
mkdir -p ${ROOTFS}/etc/apt/sources.list.d ${ROOTFS}/etc/apt/trusted.gpg.d
sed -i 's/main/main non-free non-free-firmware contrib/g' ${ROOTFS}/etc/apt/sources.list
echo "deb http://repo.mobian.org/ ${mobian_suite} main non-free non-free-firmware" > ${ROOTFS}/etc/apt/sources.list.d/mobian.list
curl -L http://repo.mobian.org/mobian.gpg -o ${ROOTFS}/etc/apt/trusted.gpg.d/mobian.gpg
chmod 644 ${ROOTFS}/etc/apt/trusted.gpg.d/mobian.gpg

cat << EOF > ${ROOTFS}/etc/apt/preferences.d/00-kali-priority
Package: *
Pin: release o=Kali
Pin-Priority: 1000
EOF

cat << EOF > ${ROOTFS}/etc/apt/preferences.d/10-mobian-priority
Package: u-boot-menu
Pin: release o=Mobian
Pin-Priority: 1001

Package: alsa-ucm-conf
Pin: release o=Mobian
Pin-Priority: 1001
EOF

ROOT_UUID=`python3 -c 'from uuid import uuid4; print(uuid4())'`
BOOT_UUID=`python3 -c 'from uuid import uuid4; print(uuid4())'`

if [[ "$family" == "sunxi" || "$family" == "rockchip" ]]
then
    BOOTPART="UUID=${BOOT_UUID}	/boot	ext4	defaults,x-systemd.growfs	0	2"
fi

cat << EOF > partuuid
ROOT_UUID=${ROOT_UUID}
BOOT_UUID=${BOOT_UUID}
EOF

cat << EOF > ${ROOTFS}/etc/fstab
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
UUID=${ROOT_UUID}	/	ext4	defaults,x-systemd.growfs	0	1
${BOOTPART}
EOF

echo '[+]Stage 3: Installing device specific and environment packages'
nspawn-exec apt update
nspawn-exec apt install -y ${PACKAGES}

echo '[+]Stage 4: Adding some extra tweaks'
if [ ! -e "${ROOTFS}/etc/repart.d/50-root.conf" ]
then
    mkdir ${ROOTFS}/etc/kali-motd
    touch ${ROOTFS}/etc/kali-motd/disable-minimal-warning
    mkdir -p ${ROOTFS}/etc/skel/.local/share/squeekboard/keyboards/terminal
    curl https://raw.githubusercontent.com/Shubhamvis98/PinePhone_Tweaks/main/layouts/us.yaml > ${ROOTFS}/etc/skel/.local/share/squeekboard/keyboards/us.yaml
    ln -sr ${ROOTFS}/etc/skel/.local/share/squeekboard/keyboards/{us.yaml,terminal/}
    sed -i 's/-0.07/0/;s/-0.13/0/' ${ROOTFS}/usr/share/plymouth/themes/kali/kali.script
    mkdir -p ${ROOTFS}/etc/repart.d
    cat << 'EOF' > ${ROOTFS}/etc/repart.d/50-root.conf
    [Partition]
    Type=root
    Weight=10000
EOF
else
    echo '[*]This has been already done'
fi

echo '[+]Stage 5: Adding user and changing default shell to zsh'
if [ ! `grep ${username} ${ROOTFS}/etc/passwd` ]
then
    nspawn-exec adduser --disabled-password --gecos "" ${username}
    sed -i "s#${username}:\!:#${username}:`echo ${password} | openssl passwd -1 -stdin`:#" ${ROOTFS}/etc/shadow
    sed -i 's/bash/zsh/' ${ROOTFS}/etc/passwd
    for i in dialout sudo audio video plugdev input render bluetooth feedbackd netdev; do
        nspawn-exec usermod -aG ${i} ${username} || true
    done
else
    echo '[*]User already present'
fi

echo '[*]Enabling kali plymouth theme'
nspawn-exec plymouth-set-default-theme -R kali
#sed -i "/picture-uri/cpicture-uri='file:\/\/\/usr\/share\/backgrounds\/kali\/kali-red-sticker-16x9.jpg'" ${ROOTFS}/usr/share/glib-2.0/schemas/11_mobile.gschema.override
sed -i "/picture-uri/cpicture-uri='file:\/\/\/usr\/share\/backgrounds\/kali\/kali-red-sticker-16x9.jpg'" ${ROOTFS}/usr/share/glib-2.0/schemas/10_desktop-base.gschema.override
nspawn-exec glib-compile-schemas /usr/share/glib-2.0/schemas

echo '[*]Update u-boot config...'
nspawn-exec u-boot-update

echo '[+]Stage 6: Enable services'
for svc in `echo ${services} | tr ' ' '\n'`
do
	nspawn-exec systemctl enable $svc
done

echo '[*]Checking for custom script'
if [ -f "${custom_script}" ]
then
    mkdir -p ${ROOTFS}/ztmpz
    cp ${custom_script} ${ROOTFS}/ztmpz
    nspawn-exec bash /ztmpz/${custom_script}
    [ -d "${ROOTFS}/ztmpz" ] && rm -rf ${ROOTFS}/ztmpz
fi

echo '[*]Tweaks and cleanup'
echo ${hostname} > ${ROOTFS}/etc/hostname
grep -q ${hostname} ${ROOTFS}/etc/hosts || \
	sed -i "1s/$/\n127.0.1.1\t${hostname}/" ${ROOTFS}/etc/hosts
nspawn-exec apt clean

echo '[*]Deploy rootfs into EXT4 image'
tar -cpzf ${ROOTFS_TAR} ${ROOTFS} && rm -rf ${ROOTFS}
mkimg ${IMG} ${IMGSIZE} ${PARTITIONS}
tar -xpf ${ROOTFS_TAR}

echo '[*]Cleanup and unmount'
cleanup

echo "[+]Stage 7: Compressing ${IMG}..."
if [ "$blockmap" ]
then
    bmaptool create ${IMG} > ${IMG}.bmap
else
    echo '[*]Skipped blockmap creation'
fi

if [ "$SPARSE" ]
then
    img2simg ${IMG} ${IMG}_SPARSE
    mv -v ${IMG}_SPARSE ${IMG}
elif [ "$compress" ]
then
    [ -f "${IMG}" ] && xz "${IMG}"
else
    echo '[*]Skipped compression'
fi
echo '[+]Image Generated.'

