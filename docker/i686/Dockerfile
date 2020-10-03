ARG GENTOO_DOCKER_BUILD_DATE=20200420


# Use the empty image with the portage tree as the first stage
FROM gentoo/portage:${GENTOO_DOCKER_BUILD_DATE} AS portage


# Target container with Gentoo Linux + necessary tools to build kernel and initramfs
FROM gentoo/stage3-x86:${GENTOO_DOCKER_BUILD_DATE} as stage

# Copy the portage tree into the current stage
COPY --from=portage /var/db /var/db

# We need busybox to embed into initramfs
RUN USE="static" emerge --quiet sys-apps/busybox

# We need cpio to pack initramfs
RUN emerge --quiet app-arch/cpio

# We need LVM to embed into initramfs
RUN FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox" USE="static static-libs" emerge --quiet sys-fs/lvm2

# We need syslinux inside container to make bootable disk image
RUN emerge --quiet sys-boot/syslinux

# Load state3 into /destination
RUN mkdir /destination
RUN LATEST_STAGE3=$(wget -qO- https://gentoo.osuosl.org//releases/x86/autobuilds/latest-stage3-i686.txt | grep -v '^#' | head -n 1 | cut -d' ' -f1) && wget -qO- "https://gentoo.osuosl.org//releases/x86/autobuilds/${LATEST_STAGE3}" | tar -xJp -C /destination

#ENV CFLAGS="-O2 -march=i686 -mmmx -msse -msse2 -msse3 -pipe -fomit-frame-pointer"
RUN echo 'USE="-bindist overlays"' >> /etc/portage/make.conf
RUN echo 'USE="-bindist overlays"' >> /destination/etc/portage/make.conf

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
RUN ROOT=/destination emerge --quiet sys-process/cronie
RUN ROOT=/destination emerge --quiet sys-process/htop
RUN ROOT=/destination emerge --quiet www-servers/apache
RUN ROOT=/destination USE="overlays" emerge --quiet net-nds/openldap
#RUN ROOT=/destination USE="dlz ldap" emerge --quiet net-dns/bind

COPY docker/i686/install.sh /support/
RUN /support/install.sh
RUN false

# TODO Set APACHE_MODULES

RUN cp /etc/group /destination/etc/group
RUN cp /etc/passwd /destination/etc/passwd
RUN cp /etc/shadow /destination/etc/shadow

# Set root password: zxteam
RUN sed -i 's/root:\*:10770:0:::::/root:\$6\$JhrvFjMHeZqHuve5$QRfSQTm0iekePwoglpLqRNRNO4j9YirfBsf6MfXnvMEr701y11WxuG2LTxcPfpR9w8obZUbFvX.VrrVPnXybh\/:18326:0:::::/g' /destination/etc/shadow

# Disable lvmetad
RUN sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /destination/etc/lvm/lvm.conf

# Add --noclear to TTY1
RUN sed -i 's/agetty 38400 tty1/agetty --noclear 38400 tty1/g' /destination/etc/inittab

# Setup fstab
RUN echo "LABEL=boot              /boot           ext4            noauto,noatime  1 2" >> /destination/etc/fstab
RUN echo "/dev/vgsys/root         /               ext4            noatime         0 1" >> /destination/etc/fstab
RUN echo "/dev/vgsys/swap         none            swap            sw              0 0" >> /destination/etc/fstab
RUN echo "/dev/vgdata/data        /data           ext4            noatime         0 2" >> /destination/etc/fstab

# Misc
RUN cp /destination/etc/lvm/lvm.conf /etc/lvm/lvm.conf

# User's data
RUN mkdir /destination/data /destination/etc/runlevels/boot/lvm

# Auto start services
RUN ln -sf /etc/init.d/lvm 


FROM stage
ARG KERNEL_VERSION=
# Install kernel sources
RUN test -z "${KERNEL_VERSION}" && { echo "KERNEL_VERSION is not set" >&2; exit 1; } || true
RUN emerge --quiet =sys-kernel/gentoo-sources-${KERNEL_VERSION}
RUN eselect kernel set 1
RUN cd /usr/src/linux && make -C usr/ gen_init_cpio && chmod +x usr/gen_init_cpio usr/gen_initramfs_list.sh
# Copy support files
COPY docker/i686/boot /support/boot
COPY docker/i686/initramfs /support/initramfs
COPY docker/i686/config-${KERNEL_VERSION}-gentoo /support/config-gentoo
COPY docker/i686/docker-entrypoint.sh /support/docker-entrypoint.sh
RUN echo "${KERNEL_VERSION}" > /support/KERNEL_VERSION
VOLUME [ "/data" ]
#ENTRYPOINT [ "/bin/bash" ]
ENTRYPOINT [ "/support/docker-entrypoint.sh" ]
