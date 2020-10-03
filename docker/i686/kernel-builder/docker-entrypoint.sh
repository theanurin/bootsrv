#!/bin/bash
#

set -e

if [ ! -f /kernel-version ]; then
	echo "Look like you have wrong build container. The container should present a file /kernel-version"
	exit 1
fi

KERNEL_VERSION=$(cat /kernel-version)
if [ -z "${KERNEL_VERSION}" ]; then
	echo "Look like you have wrong build container. The container should present a file /kernel-version with proper kernel version."
	exit 1
fi

function initramfs() {
	# Make initramfs directory (that will included into kernel)
	mkdir --parents /usr/src/initramfs/{bin,dev,etc,lib,mnt/root,proc,root,sbin,sys} && \
	mknod -m 666 /usr/src/initramfs/dev/null c 1 3 && \
	mknod -m 666 /usr/src/initramfs/dev/tty c 5 0 && \
	mknod -m 600 /usr/src/initramfs/dev/console c 5 1 && \
	cp --archive /bin/busybox /usr/src/initramfs/bin/busybox

	# Copy /init script (the executable in the root of the initramfs that is executed by the kernel)
	cp /support/initramfs/init /usr/src/initramfs/init
	# Make /init script executablels
	chmod +x /usr/src/initramfs/init
	# LVM configuration
	cp --archive /etc/lvm /usr/src/initramfs/etc/ && sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /usr/src/initramfs/etc/lvm/lvm.conf

	# Copy ld-linux lib
	cp --archive /lib/ld* /usr/src/initramfs/lib/

	# Copy libnss-files lib
	cp --archive /lib/libnss_files* /usr/src/initramfs/lib/

	# Copy libs
	cp --archive /lib/* /usr/src/initramfs/lib/
	cp /sbin/lvm /usr/src/initramfs/sbin/lvm

	# Copy lvm with dependency libraries
	#for L in $(ldd /sbin/lvm | grep "=> /" | awk '{print $3}'); do cp --archive "$L" "/usr/src/initramfs/$L"; if [ -h "$L" ]; then REAL_L=$(readlink -f "$L"); cp --archive "$REAL_L" "/usr/src/initramfs$REAL_L"; fi; done; 

	ln -s lvm /usr/src/initramfs/sbin/vgchange && ln -s lvm /usr/src/initramfs/sbin/vgscan

	# Pack initramfs
	cd /usr/src/initramfs && find . -print0 | cpio --null --create --format=newc | gzip --best > /data/initramfs-${KERNEL_VERSION}.cpio.gz
}

function kernel() {
	cp /support/kernel/config-${KERNEL_VERSION}-gentoo /data/config-${KERNEL_VERSION}-gentoo

	# Check that kernel config has correct settings for initramfs
	if ! grep 'CONFIG_RD_GZIP=y' /data/config-${KERNEL_VERSION}-gentoo >/dev/null 2>&1; then
		echo "Kernel configuration must include CONFIG_RD_GZIP=y" >&2
		exit 1
	fi

	export KCONFIG_CONFIG=/data/config-${KERNEL_VERSION}-gentoo
	cd /usr/src/linux
	make menuconfig
	make "-j$(nproc)"
	/bin/bash
	make "-j$(nproc)" modules
	/bin/bash
	make install
	make modules_install
}

case "$1" in
	shell)
		exec /bin/bash
		;;
	*)
		kernel
		initramfs
esac