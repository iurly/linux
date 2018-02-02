HOST=10.0.1.173
USER=pi

SSH_HOST="${USER}@${HOST}"

make -j 4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules M=drivers/net/can
mkdir -p __mcp_fs__
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=__mcp_fs__/ modules_install M=drivers/net/can

scp drivers/net/can/spi/mcp251x.ko ${SSH_HOST}:/tmp
ssh ${SSH_HOST} "sudo rmmod mcp251x; sudo insmod /tmp/mcp251x.ko"
