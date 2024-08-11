#!/bin/bash

DEVICE="$1"

generate_bootimg()
{
OPTIONS=r:s:v:m:w:k:d:t:
LONGOPTIONS=rootdev:,soc:,vendor:,model:,variant:,kerneladdr:,ramdiskaddr:,tagsaddr:

PARSED=$(getopt -o $OPTIONS -l $LONGOPTIONS -- "$@")
if [ "$?" != "0" ]; then
  exit
fi
eval set -- "$PARSED"

# Default values
ROOTDEV=""
SOC=""
VENDOR=""
MODEL=""
VARIANT=""
KERNELADDR="0x8000"
RAMDISKADDR="0x1000000"
TAGSADDR="0x100"
KERNEL_VERSION=$(linux-version list | tail -1)

while true
do
	case "$1" in
		-r|--rootdev)
			ROOTDEV="$2"
			shift 2;;
		-s|--soc)
			SOC="$2"
			shift 2;;
		-v|--vendor)
			VENDOR="$2"
			shift 2;;
		-m|--model)
			MODEL="$2"
			shift 2;;
		-w|--variant)
			VARIANT="$2"
			shift 2;;
		-k|--kerneladdr)
			KERNELADDR="$2"
			shift 2;;
		-d|--ramdiskaddr)
			RAMDISKADDR="$2"
			shift 2;;
		-t|--tagsaddr)
			TAGSADDR="$2"
			shift 2;;
		*)
			break;;
	esac
done

echo """
ROOTDEV: $ROOTDEV
SOC: $SOC
VENDOR: $VENDOR
MODEL: $MODEL
VARIANT: $VARIANT
KERNELADDR: $KERNELADDR
RAMDISKADDR: $RAMDISKADDR
TAGSADDR: $TAGSADDR
"""

CMDLINE="mobile.qcomsoc=${SOC} mobile.vendor=${VENDOR} mobile.model=${MODEL}"
if [ "${VARIANT}" ]; then
	CMDLINE="${CMDLINE} mobile.variant=${VARIANT}"
	FULLMODEL="${MODEL}-${VARIANT}"
else
	FULLMODEL="${MODEL}"
fi

# Workaround a bug in the SDHCI driver on SM7225
if [ "${SOC}" = "qcom/sm7225" ]; then
	CMDLINE="${CMDLINE} sdhci.debug_quirks=0x40"
fi

# Append DTB to kernel
echo "Creating boot image for ${FULLMODEL}..."
cat /boot/vmlinuz-${KERNEL_VERSION} \
	/usr/lib/linux-image-${KERNEL_VERSION}/${SOC}-${VENDOR}-${FULLMODEL}.dtb > /tmp/kernel-dtb

# Create the bootimg as it's the only format recognized by the Android bootloader

abootimg --create /boot_${FULLMODEL}_`date +%Y%m%d`.img -c kerneladdr=${KERNELADDR} \
	-c ramdiskaddr=${RAMDISKADDR} -c secondaddr=0x0 -c tagsaddr=${TAGSADDR} -c pagesize=4096 \
	-c cmdline="mobile.root=${ROOTDEV} ${CMDLINE} init=/sbin/init ro quiet splash" \
	-k /tmp/kernel-dtb -r /boot/initrd.img-${KERNEL_VERSION}
}

ROOTPART=`grep -P '^UUID.*[ \t]/[ \t]' /etc/fstab | awk '{print $1}'`

if [ "${ROOTPART}" = "UUID=" ]; then
	# This means we're using an encrypted rootfs
	ROOTPART="/dev/mapper/root"
fi
KERNEL_VERSION=$(linux-version list)

case "${DEVICE}" in
	"sdm845")
		generate_bootimg -r "${ROOTPART}" -s "qcom/sdm845" -v "oneplus" -m "enchilada"
		generate_bootimg -r "${ROOTPART}" -s "qcom/sdm845" -v "oneplus" -m "fajita"
		generate_bootimg -r "${ROOTPART}" -s "qcom/sdm845" -v "shift" -m "axolotl"
		generate_bootimg -r "${ROOTPART}" -s "qcom/sdm845" -v "xiaomi" -m "beryllium" -w "tianma"
		generate_bootimg -r "${ROOTPART}" -s "qcom/sdm845" -v "xiaomi" -m "beryllium" -w "ebbg"
		generate_bootimg -r "${ROOTPART}" -s "qcom/sdm845" -v "xiaomi" -m "polaris"
		;;
	"sm7225")
		generate_bootimg -r "${ROOTPART}" -s "qcom/sm7225" -v "fairphone" -m "fp4"
		;;
	"sm7325")
		generate_bootimg -r "${ROOTPART}" -s "qcom/sm7325" -v "nothing" -m "spacewar" -k 0x10000000 -d 0x10000000 -t 0x10000000
		;;
	*)
		echo "ERROR: unsupported device ${DEVICE}"
		exit 1
		;;
esac
