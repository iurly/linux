# Make sure script terminates in case of errors
set -e

HOST=10.0.1.173
USER=pi

LINUX_PATH=$PWD
DRIVER_PATH=${LINUX_PATH}/drivers/tty/serial/
DT_PATH=${LINUX_PATH}/arch/arm/boot/dts/overlays/


SSH_HOST="${USER}@${HOST}"
KERNEL=kernel7
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- bcm2709_defconfig
make -j 4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules_prepare
make -j 4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules M=drivers/tty/serial
make -j 4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules M=drivers/base
#mkdir -p __mcp_fs__
#make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=__mcp_fs__/ modules_install M=drivers/net/can

./scripts/dtc/dtc -@ -I dts -O dtb -o ${DT_PATH}/scs-max3107-spi0.dtbo ${DT_PATH}scs-max3107-spi0-overlay.dts

cat >max_startup.sh << __EOF__
set -e
sudo rmmod max310x.ko || true
sudo rmmod regmap-spi.ko || true
sudo insmod -f /tmp/regmap-spi.ko
sudo insmod -f /tmp/max310x.ko max310x_enable_dma=1

echo "Removing old device tree if present"
# Remove (old) device tree overlay, if present
sudo dtoverlay -r 0 || true

echo "Releasing chip select for LORA device"
# Release chip select for LORA device
echo 25 > /sys/class/gpio/export 2>/dev/null || true
sleep .5
echo out > /sys/class/gpio/gpio25/direction
echo 1 > /sys/class/gpio/gpio25/value

echo "Resetting max3107"
# Reset device
echo 8 > /sys/class/gpio/export 2>/dev/null || true
sleep .5
echo out > /sys/class/gpio/gpio8/direction
echo 0 > /sys/class/gpio/gpio8/value
echo 1 > /sys/class/gpio/gpio8/value

echo "loading DT overlay"
# Load DT overlay
sudo dtoverlay -d /tmp scs-max3107-spi0

# List overlays
dtoverlay -l

# Set baudrate
stty -F /dev/ttyMAX0 speed 2000000

# Output some string
echo 0123456789 > /dev/ttyMAX0

# Activate LED3/BCM21 of the expansion board which we might use for debugging and tracing with logic analyzer using PIN 40 of the header
echo "Activating LED3 (blue)"
echo 21 > /sys/class/gpio/export 2>/dev/null || true
sleep .5
echo out > /sys/class/gpio/gpio21/direction
echo 1 > /sys/class/gpio/gpio21/value

echo "max3107 initialized successfully"
__EOF__

scp ${DRIVER_PATH}/max310x.ko drivers/base/regmap/regmap-spi.ko ${DT_PATH}/scs-max3107-spi0.dtbo max_startup.sh ${SSH_HOST}:/tmp
ssh ${SSH_HOST} "chmod a+x /tmp/max_startup.sh; /tmp/max_startup.sh"
