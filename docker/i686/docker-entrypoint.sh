#!/bin/bash
#

set -e

if [ ! -f /support/KERNEL_VERSION ]; then
	echo "Look like you have wrong build container. The container should present a file /support/KERNEL_VERSION"
	exit 1
fi
KERNEL_VERSION=$(cat /support/KERNEL_VERSION)
if [ -z "${KERNEL_VERSION}" ]; then
	echo "Look like you have wrong build container. The container should present a file /support/KERNEL_VERSION with proper kernel version."
	exit 1
fi


if [ ! -d "/data/.kernel-${KERNEL_VERSION}" ]; then
	echo "Creating kernel build directory..."
	mkdir "/data/.kernel-${KERNEL_VERSION}"
fi
if [ ! -f "/data/.kernel-${KERNEL_VERSION}/.config" ]; then
	echo "Initialize kernel configuration..."
	cp /support/config-gentoo "/data/.kernel-${KERNEL_VERSION}/.config"
fi
if [ ! -d /data/.initramfs ]; then
	echo "Initialize initramfs configuration..."
	cp -a /support/initramfs /data/.initramfs
fi
if [ ! -d /data/boot ]; then
	echo "Initialize boot dir..."
	mkdir /data/boot
fi


function config_kernel() {
	cd /usr/src/linux
	KBUILD_OUTPUT="/data/.kernel-${KERNEL_VERSION}" make menuconfig
}

function build_kernel() {
	# Check that kernel config has correct settings for initramfs
	if ! grep 'CONFIG_RD_GZIP=y' "/data/.kernel-${KERNEL_VERSION}/.config" >/dev/null 2>&1; then
		echo "Kernel configuration must include CONFIG_RD_GZIP=y" >&2
		exit 1
	fi

	cd "/usr/src/linux-${KERNEL_VERSION}-gentoo"
	KBUILD_OUTPUT="/data/.kernel-${KERNEL_VERSION}" make "-j$(nproc)"
	KBUILD_OUTPUT="/data/.kernel-${KERNEL_VERSION}" make "-j$(nproc)" modules
	KBUILD_OUTPUT="/data/.kernel-${KERNEL_VERSION}" INSTALL_PATH=/data/boot make install
	KBUILD_OUTPUT="/data/.kernel-${KERNEL_VERSION}" make modules_install
	mv "/lib/modules/${KERNEL_VERSION}-gentoo" "/data/modules-${KERNEL_VERSION}-gentoo"
}

function build_initramfs() {
	if [ ! -d "/data/modules-${KERNEL_VERSION}-gentoo" ]; then
		echo "ERROR. Directory /data/modules-${KERNEL_VERSION}-gentoo is not exist. Did you build kernel first?" >&2
		exit 1
	fi

	local CPIO_LIST=$(mktemp)
	cat /data/.initramfs/initramfs_list >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"
	echo "file /init /data/.initramfs/init 755 0 0" >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"
	echo "# Modules" >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"

	cd "/data/modules-${KERNEL_VERSION}-gentoo"
	for n in $(find *); do
		echo "Adding module $n..."
		[ -d $n ] && echo "dir /lib/modules/$n 700 0 0" >> "${CPIO_LIST}"
		[ -f $n ] && echo "file /lib/modules/$n /data/modules-${KERNEL_VERSION}-gentoo/$n 600 0 0" >> "${CPIO_LIST}"
	done

	cd "/usr/src/linux-${KERNEL_VERSION}-gentoo"
	./usr/gen_initramfs_list.sh -o "/data/boot/initramfs-${KERNEL_VERSION}-gentoo.cpio.gz" "${CPIO_LIST}"

	# Debugging
	[ -d "/data/initramfs-${KERNEL_VERSION}-gentoo" ] && rm -rf "/data/initramfs-${KERNEL_VERSION}-gentoo"
	mkdir "/data/initramfs-${KERNEL_VERSION}-gentoo"
	cd "/data/initramfs-${KERNEL_VERSION}-gentoo"
	zcat "/data/boot/initramfs-${KERNEL_VERSION}-gentoo.cpio.gz" | cpio --extract
	#exec chroot . /bin/busybox sh -i
}

function build_initramfs_obsolete() {
	/usr/src/linux/usr/gen_initramfs_list.sh -o /data/initramfs.cpio.gz /data/.initramfs/initramfs_list
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

function build_image() {
	local IMAGE_SIZE_MB=2048
	local IMAGE_FILE=/data/everyboot.img
	local SWAP_SIZE_MB=128

	for LOOP_INDEX in $(seq 0 9); do
		if [ ! -b /dev/loop${LOOP_INDEX} ]; then
			mknod /dev/loop${LOOP_INDEX} -m0660 b 7 ${LOOP_INDEX}
		fi
	done

	echo
	echo -n "Searching for available loop device... "
	LO_DEV=$(losetup --find) || exit 1
	echo "Found ${LO_DEV}"

	echo
	echo -n "Creating ${IMAGE_FILE} ${IMAGE_SIZE_MB}M image ... "
	truncate "--size=${IMAGE_SIZE_MB}M" "${IMAGE_FILE}" || exit 2
	echo "Done"

	vgchange -an
	losetup --detach-all

	echo
	echo -n "Setting loop device ${LO_DEV} => ${IMAGE_FILE} ... "
	losetup "${LO_DEV}" "${IMAGE_FILE}" || exit 3
	echo "Done"

	echo
	echo "Make partitions... "
	echo ",128M,,*
	;
	" | sfdisk --wipe always --label dos --no-reread --no-tell-kernel "${LO_DEV}" || exit 4
	sfdisk --part-type "${LO_DEV}" 1 83 || exit 4
	sfdisk --part-type "${LO_DEV}" 2 8e || exit 4

	echo
	echo -n "Re-setting loop device ${LO_DEV} => ${IMAGE_FILE} with --partscan option ... "
	losetup --detach "${LO_DEV}" || exit 5
	losetup --partscan "${LO_DEV}" "${IMAGE_FILE}" || exit 6
	echo "Done"

	echo
	echo "Fixing loop partitions ... "
	PARTITIONS=$(lsblk --raw --output "MAJ:MIN" --noheadings "${LO_DEV}" | tail -n +2)
	COUNTER=1
	for i in $PARTITIONS; do
		MAJ=$(echo $i | cut -d: -f1)
		MIN=$(echo $i | cut -d: -f2)
		if [ ! -e "${LO_DEV}p${COUNTER}" ]; then 
			mknod ${LO_DEV}p${COUNTER} b $MAJ $MIN
		fi
		echo "	${LO_DEV}p${COUNTER}"
		COUNTER=$((COUNTER + 1))
	done
	echo "Done"

	echo
	echo "Checking Volume Group 'vgsys' is not exists"
	vgs vgsys >/dev/null 2>&1 && exit 7

	echo
	echo "Creating Physical Volume on ${LO_DEV}p2 ... "
	pvcreate --force "${LO_DEV}p2" || exit 9

	echo
	echo "Creating Volume Group 'vgsys' on ${LO_DEV}p2 ... "
	vgcreate vgsys "${LO_DEV}p2" || exit 10

	echo
	echo "Creating Logical Volume 'swap' on vgsys ... "
	lvcreate --name swap --size "${SWAP_SIZE_MB}M" --zero n vgsys || exit 11

	echo
	echo "Creating Logical Volume 'root' on vgsys ... "
	lvcreate --name root --extents 100%FREE --zero n vgsys || exit 12

	echo
	echo "Making Volume Group's nodes ... "
	vgscan --mknodes || exit 13

	# echo
	# echo "Fixing loop partitions ... "
	# lsblk --raw --output "NAME,MAJ:MIN" --noheadings "${LO_DEV}p2" | grep -e '^vgsys-' |  while read i; do
	# 	NAME=$(echo $i | cut -d' ' -f1)
	# 	MAJ=$(echo $i | cut -d' ' -f2 | cut -d: -f1)
	# 	MIN=$(echo $i | cut -d' ' -f2 | cut -d: -f2)
	# 	if [ ! -e "/dev/mapper/$NAME" ]; then 
	# 		mknod "/dev/mapper/$NAME" b $MAJ $MIN
	# 	fi
	# 	echo "	$NAME $MAJ $MIN"
	# done
	# echo "Done"

	echo
	echo "Creating ext4 filesystem on ${LO_DEV}p1 ... "
	mkfs.ext4 -L boot "${LO_DEV}p1" || exit 8

	echo
	echo "Making swap on /dev/vgsys/swap ..."
	mkswap -L swap "/dev/vgsys/swap" || exit 14

	echo
	echo "Making ext4 filesystem on /dev/vgsys/root ..."
	mkfs.ext4 -L root -N 524288 "/dev/vgsys/root" || exit 15

	umask 0022

	echo
	echo "Mounting root filesystem..."
	mkdir /mnt/gentoo
	mount /dev/vgsys/root /mnt/gentoo || exit 16

	echo
	echo "Copying stage3 + precompiled files... "
	time cp -a /destination/* /mnt/gentoo || exit 17
	# time cp -a /bin /boot /etc /home /lib /media /opt /root /sbin /usr /var /mnt/gentoo/

	echo
	echo "Mounting boot filesystem..."
	time mount "${LO_DEV}p1" /mnt/gentoo/boot || exit 18

	echo
	echo "Setup boot loader..."
	time extlinux --install             /mnt/gentoo/boot/ || exit 19
	cp /usr/share/syslinux/libcom32.c32 /mnt/gentoo/boot/ || exit 19
	cp /usr/share/syslinux/libutil.c32  /mnt/gentoo/boot/ || exit 19
	cp /usr/share/syslinux/memdisk      /mnt/gentoo/boot/ || exit 19
	cp /usr/share/syslinux/menu.c32     /mnt/gentoo/boot/ || exit 19
	cp /usr/share/syslinux/vesamenu.c32 /mnt/gentoo/boot/ || exit 19

	echo "Copying MBR boot sector (first 440 bytes)..."
	time dd if=/usr/share/syslinux/mbr.bin of="${LO_DEV}" bs=440 count=1 conv=notrunc || exit 20

	echo "Copying content of /boot ..."
	time cp -a /support/boot/* /mnt/gentoo/boot/ || exit 21
	time cp -a /data/boot/* /mnt/gentoo/boot/ || exit 21

	# Add setup markers
	touch /mnt/gentoo/SETUP.0a0507ad-7184-4f5a-837c-96cb1d612505

	echo
	echo "Zero-ing empty space..."
	dd if=/dev/zero of=/mnt/gentoo/null.dat >/dev/null 2>&1 || true
	rm /mnt/gentoo/null.dat

	echo
	echo "Destructing..."
	umount /mnt/gentoo/boot
	umount /mnt/gentoo
	vgchange -an vgsys
	losetup --detach "${LO_DEV}"

	#echo
	#echo "Calculating SHA1 of the image ${IMAGE_FILE} ..."
	#sha1sum "${IMAGE_FILE}" | tee "${IMAGE_FILE}.sha1"

	#echo
	#echo "ZIP image ${IMAGE_FILE} ..."
	#cat "${IMAGE_FILE}" | gzip > "${IMAGE_FILE}.gz"

	echo
	echo "Your image is ready"
	echo
}

case "$1" in
	shell)
		exec /bin/bash
		;;
	config)
		config_kernel
		;;
	kernel)
		build_kernel
		;;
	initramfs)
		build_initramfs
		;;
	image)
		build_image
		;;
	all)
		build_kernel
		build_initramfs
		build_image
		;;
	*)
		echo >&2
		echo "ERROR! Wrong command argumnent" >&2
		echo >&2
		echo "	Use one of shell, config, kernel, initramfs, image or all" >&2
		echo >&2
		exit 1
		;;
esac
