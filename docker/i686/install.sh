#!/bin/bash
#

echo "Hello"

mount --types proc none /destination/proc
mount --rbind /sys /destination/sys
mount --make-rslave /destination/sys
mount --rbind /dev /destination/dev
mount --make-rslave /destination/dev

cat << EOF | chroot /destination
emerge -pvNDu world
EOF

umount -l /destination/dev{/shm,/pts,}
