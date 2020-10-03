ARG GENTOO_DOCKER_BUILD_DATE=20200310

# Use the empty image with the portage tree as the first stage
FROM gentoo/portage:${GENTOO_DOCKER_BUILD_DATE} AS portage


# Gentoo stage3 is the second stage, basically an unpacked Gentoo Linux
FROM gentoo/stage3-x86:${GENTOO_DOCKER_BUILD_DATE}
ARG GENTOO_STAGE3_XZ_URL="https://bouncer.gentoo.org/fetch/root/all/releases/x86/autobuilds/20200211T214502Z/stage3-i686-20200211T214502Z.tar.xz"

# Copy the portage tree into the current stage
COPY --from=portage /var/db /var/db

# Load state3 into /destination
RUN mkdir /destination
RUN wget -qO- "${GENTOO_STAGE3_XZ_URL}" | tar -xJp -C /destination

# ENV CFLAGS="-march=i686 -mmmx -msse -msse2 -msse3 -O2 -pipe -fomit-frame-pointer"
# ENV USE="bindist ipv6"

# Emerge necessary packages
RUN ROOT=/destination emerge --quiet app-portage/gentoolkit
RUN ROOT=/destination emerge --quiet app-admin/sudo
RUN ROOT=/destination emerge --quiet app-admin/syslog-ng
RUN ROOT=/destination emerge --quiet app-arch/cpio
RUN ROOT=/destination emerge --quiet app-misc/mc
RUN ROOT=/destination emerge --quiet app-misc/screen
RUN ROOT=/destination emerge --quiet app-portage/cpuid2cpuflags
RUN ROOT=/destination emerge --quiet net-fs/nfs-utils
RUN ROOT=/destination emerge --quiet net-ftp/tftp-hpa
RUN ROOT=/destination emerge --quiet net-misc/dhcp
RUN ROOT=/destination emerge --quiet net-misc/dhcpcd
RUN ROOT=/destination emerge --quiet net-misc/ntp
RUN ROOT=/destination emerge --quiet net-misc/vconfig
RUN ROOT=/destination emerge --quiet sys-apps/ethtool
RUN ROOT=/destination emerge --quiet sys-block/tgt
RUN ROOT=/destination emerge --quiet sys-boot/syslinux
RUN ROOT=/destination emerge --quiet sys-fs/lvm2
RUN ROOT=/destination emerge --quiet sys-fs/multipath-tools
RUN ROOT=/destination emerge --quiet sys-kernel/dracut
#RUN ROOT=/destination emerge --quiet sys-kernel/gentoo-sources
RUN ROOT=/destination emerge --quiet sys-process/cronie
RUN ROOT=/destination emerge --quiet sys-process/htop

# Set root password: zxteam
RUN sed -i 's/root:\*:10770:0:::::/root:\$6\$JhrvFjMHeZqHuve5$QRfSQTm0iekePwoglpLqRNRNO4j9YirfBsf6MfXnvMEr701y11WxuG2LTxcPfpR9w8obZUbFvX.VrrVPnXybh\/:18326:0:::::/g' /destination/etc/shadow

# Disable lvmetad
RUN sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /destination/etc/lvm/lvm.conf

# Setup fstab
RUN echo "LABEL=boot              /boot           ext2            noauto,noatime  1 2" >> /destination/etc/fstab
RUN echo "/dev/vg0/system         /               ext4            noatime         0 1" >> /destination/etc/fstab
RUN echo "/dev/vg0/swap           none            swap            sw              0 0" >> /destination/etc/fstab

# We need syslinux inside container
RUN emerge --quiet sys-boot/syslinux

# Cleanup
#RUN rm -rf /var/db/* /var/cache/*
#RUN rm -rf /var/tmp/portage
#RUN find /var/log -type f -name '*.log' -exec rm {} \;

#RUN sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf

COPY docker/i686/boot /support/stage/boot
COPY docker/i686/docker-entrypoint.sh /support/docker-entrypoint.sh

ENTRYPOINT [ "/support/docker-entrypoint.sh" ]
