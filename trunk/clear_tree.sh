#!/bin/sh

ROOTDIR=`pwd`
export ROOTDIR=$ROOTDIR

# Set toolchain default dir (may be redifined in ${ROOTDIR}/.config)
export CONFIG_TOOLCHAIN_DIR="${ROOTDIR}/../toolchain/out"

if [ ! -f "$ROOTDIR/.config" ]; then
	echo "Project config file .config not found! Terminate."
	exit 1
fi

# load project root config
. $ROOTDIR/.config

kernel_id="3.4.x"
kernel_cd="$ROOTDIR/configs/boards/$CONFIG_VENDOR/$CONFIG_FIRMWARE_PRODUCT_ID"
kernel_tf="$ROOTDIR/linux-$kernel_id/.config"
kernel_cf="${kernel_cd}/kernel-${kernel_id}.config"

if [ ! -f "$kernel_cf" ]; then
        echo "Target kernel config ($kernel_cf) not found! Terminate."
        exit 1
fi
# copy kernel config
cp -fL "$kernel_cf" "$kernel_tf"

echo "-------------CLEAN-ALL---------------"
rm -rf $ROOTDIR/stage
make clean

rm -rfv $ROOTDIR/romfs
rm -rfv $ROOTDIR/images
rm -rfv $ROOTDIR/stage
rm -f $ROOTDIR/build.log $ROOTDIR/../build.log
rm -rf $ROOTDIR/linux-$kernel_id/drivers/net/wireless/ralink/rt2860v2 \
       $ROOTDIR/linux-$kernel_id/drivers/net/wireless/ralink/rt3090 \
       $ROOTDIR/linux-$kernel_id/drivers/net/wireless/ralink/rt5392 \
       $ROOTDIR/linux-$kernel_id/drivers/net/wireless/ralink/rt5592 \
       $ROOTDIR/linux-$kernel_id/drivers/net/wireless/ralink/rt3593 \
       $ROOTDIR/linux-$kernel_id/drivers/net/wireless/ralink/mt7610 \
       $ROOTDIR/linux-$kernel_id/drivers/net/wireless/ralink/mt76x2 \
       $ROOTDIR/linux-$kernel_id/drivers/net/wireless/ralink/mt76x3 \
       $ROOTDIR/linux-$kernel_id/drivers/net/wireless/ralink/mt7628 \
       $ROOTDIR/linux-$kernel_id/drivers/net/wireless/ralink/mt7615
rm -f $ROOTDIR/linux-$kernel_id/net/nat/hw_nat/*.c \
      $ROOTDIR/linux-$kernel_id/net/nat/hw_nat/*.h

if [ -d "$ROOTDIR/../.git" ]; then
	echo "Restoring churned repository files..."
	git -C "$ROOTDIR/.." restore .
	# Ensure autotools generated files are newer than configure.ac/aclocal.m4 to prevent automake version mismatch on modern hosts
	find "$ROOTDIR/libs" "$ROOTDIR/user" "$ROOTDIR/tools" -name "Makefile.in" -exec touch {} + 2>/dev/null || true
	find "$ROOTDIR/libs" "$ROOTDIR/user" "$ROOTDIR/tools" -name "config.h.in" -exec touch {} + 2>/dev/null || true
fi

