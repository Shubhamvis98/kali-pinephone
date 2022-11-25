#!/bin/bash

. funcs.sh

set -e
cd `dirname $0`

# Creating blank image, make partitions and mount for rootfs
mkimg phosh_rel_pp.img 5

echo '[*]Stage 1: Debootstrap'
[ ! -e kali_rootfs/debootstrap/debootstrap ] && [ -e kali_rootfs/etc/passwd ] && echo -e "[*]Debootstrap already done.b\nSkipping Debootstrap..." || debootstrap --foreign --arch $ARCH kali-rolling $ROOTFS http://kali.download/kali

echo '[*]Stage 2: Debootstrap Second Stage'
rsync -rl third_stage $ROOTFS/
[ -e $ROOTFS/etc/passwd ] && echo '[*]Second Stage already done' || nspawn-exec /third_stage/second_stage

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

