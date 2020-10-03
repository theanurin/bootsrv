#!/bin/bash
#

IMAGE_SIZE_MB=2048
IMAGE_FILE=/data/disk.img
SWAP_SIZE_MB=128

#set -eo

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
echo ",512M,,*
;
" | sfdisk --wipe always --label dos --no-reread --no-tell-kernel "${LO_DEV}" || exit 4

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
echo "Checking Volume Group 'vg0' is not exists"
vgs vg0 >/dev/null 2>&1 && exit 7

echo
echo "Creating Physical Volume on ${LO_DEV}p2 ... "
pvcreate --force "${LO_DEV}p2" || exit 9

echo
echo "Creating Volume Group 'vg0' on ${LO_DEV}p2 ... "
vgcreate vg0 "${LO_DEV}p2" || exit 10

echo
echo "Creating Logical Volume 'swap' on vg0 ... "
lvcreate --name swap --size "${SWAP_SIZE_MB}M" --zero n vg0 || exit 11

echo
echo "Creating Logical Volume 'system' on vg0 ... "
lvcreate --name system --extents 100%FREE --zero n vg0 || exit 12

echo
echo "Making Volume Group's nodes ... "
vgscan --mknodes || exit 13

# echo
# echo "Fixing loop partitions ... "
# lsblk --raw --output "NAME,MAJ:MIN" --noheadings "${LO_DEV}p2" | grep -e '^vg0-' |  while read i; do
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
echo "Creating ext2 filesystem on ${LO_DEV}p1 ... "
mkfs.ext2 -L boot "${LO_DEV}p1" || exit 8


echo
echo "Making swap on /dev/vg0/swap ..."
mkswap -L swap "/dev/vg0/swap" || exit 14

echo
echo "Making ext4 filesystem on /dev/vg0/swap ..."
mkfs.ext4 -L system "/dev/vg0/system" || exit 15

umask 0022


mkdir /mnt/gentoo
mount /dev/vg0/system /mnt/gentoo

echo
echo "Coping files... "
time cp -a /destination/* /mnt/gentoo
# time cp -a /bin /boot /etc /home /lib /media /opt /root /sbin /usr /var /mnt/gentoo/

#mkdir /mnt/gentoo/boot
mount "${LO_DEV}p1" /mnt/gentoo/boot

echo
echo "Setup boot loader..."
extlinux --install /mnt/gentoo/boot
cp /destination/usr/share/syslinux/libcom32.c32 /mnt/gentoo/boot/
cp /destination/usr/share/syslinux/libutil.c32 /mnt/gentoo/boot/
cp /destination/usr/share/syslinux/memdisk /mnt/gentoo/boot/
cp /destination/usr/share/syslinux/menu.c32 /mnt/gentoo/boot/
cp /destination/usr/share/syslinux/vesamenu.c32 /mnt/gentoo/boot/
dd if=/destination/usr/share/syslinux/mbr.bin of="${LO_DEV}" bs=440 count=1 conv=notrunc

time cp -a /support/stage/boot/* /mnt/gentoo/boot/

#dracut --no-kernel --module lvm --kver 4.19.97 --gzip

echo
echo "Zero-ing empty space..."
dd if=/dev/zero of=/mnt/gentoo/null.dat
rm /mnt/gentoo/null.dat

echo
echo "Destructing..."
umount /mnt/gentoo/boot
umount /mnt/gentoo
vgchange -an vg0
losetup --detach "${LO_DEV}"

echo
echo "Calculating SHA1 of the image ${IMAGE_FILE} ..."
sha1sum "${IMAGE_FILE}" | tee "${IMAGE_FILE}.sha1"

echo
echo "ZIP image ${IMAGE_FILE} ..."
cat "${IMAGE_FILE}" | gzip > "${IMAGE_FILE}.gz"


echo
echo "Your image is ready"
exec /bin/bash
