#!/bin/busybox sh

[ -c /dev/null ]    || mknod -m 666 /dev/null c 1 3
[ -c /dev/console ] || mknod -m 600 /dev/console c 5 1

mount -t proc -o noexec,nosuid,nodev proc /proc
mount -t sysfs -o noexec,nosuid,nodev sysfs /sys

echo 0 > /proc/sys/kernel/printk

# Set up busybox'es symlinks
/bin/busybox --install -s

#echo /sbin/mdev > /proc/sys/kernel/hotplug
/bin/busybox mdev -s || /bin/sh

/sbin/vgchange --activate y vg0 || /bin/sh
/sbin/vgscan --mknodes || /bin/sh

# Mount the root filesystem.
mount -o ro /dev/vg0/system /mnt/root || /bin/sh

#echo "" > /proc/sys/kernel/hotplug

echo 1 > /proc/sys/kernel/printk

# Clean up.
umount /proc
umount /sys

# Boot the real thing.
exec switch_root /mnt/root /sbin/init