#!/bin/bash

source ./funcs.sh

set -e
cd `dirname $0`

# Creating blank image, make partitions and mount for rootfs
mkimg phosh_rel_pp.img 5

echo '[*]Stage 1: Debootstrap'
[ -e $ROOTFS/debootstrap/debootstrap ] && echo -e "[*]Debootstrap already done.\nSkipping Debootstrap..." || debootstrap --foreign --arch $ARCH kali-rolling $ROOTFS http://kali.download/kali

echo '[*]Stage 2: Debootstrap Second Stage and adding mobian apt repo'
rsync -rl third_stage $ROOTFS/
[ -e $ROOTFS/etc/passwd ] && echo '[*]Second Stage already done' || nspawn-exec /third_stage/second_stage
mkdir -p $ROOTFS/etc/apt/sources.list.d $ROOTFS/etc/apt/trusted.gpg.d
echo 'deb http://kali.download/kali kali-rolling main non-free contrib' > $ROOTFS/etc/apt/sources.list
echo 'deb http://repo.mobian.org/ trixie main non-free-firmware' > $ROOTFS/etc/apt/sources.list.d/mobian.list
curl https://salsa.debian.org/Mobian-team/mobian-recipes/-/raw/master/overlays/apt/trusted.gpg.d/mobian.gpg > $ROOTFS/etc/apt/trusted.gpg.d/mobian.gpg

cat << EOF > $ROOTFS/etc/apt/preferences.d/00-kali-priority
Package: *
Pin: release o=Kali
Pin-Priority: 1000
EOF

cat << EOF > ${ROOTFS}/etc/fstab
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
UUID=`blkid -s UUID -o value $ROOT_P`	/	ext4	defaults	0	1
UUID=`blkid -s UUID -o value $BOOT_P`	/boot	ext4	defaults	0	2
EOF

echo '[*]Stage 3: Installing Extra Packages'
nspawn-exec /third_stage/third_stage

# Cleanup and Unmount
rm -rf $ROOTFS/third_stage
umount $ROOTFS/boot
umount $ROOTFS
rmdir $ROOTFS
losetup -D
echo '[*]PinePhone Image Generated.'

