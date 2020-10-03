ARG GENTOO_DOCKER_BUILD_DATE=20200310


# Use the empty image with the portage tree as the first stage
FROM gentoo/portage:${GENTOO_DOCKER_BUILD_DATE} AS portage


# Gentoo stage3 is the second stage, basically an unpacked Gentoo Linux
FROM gentoo/stage3-x86:${GENTOO_DOCKER_BUILD_DATE}
ARG KERNEL_VERSION=4.19.97
# Copy the portage tree into the current stage
COPY --from=portage /var/db /var/db
# Install kernel sources
RUN emerge --quiet =sys-kernel/gentoo-sources-${KERNEL_VERSION}
# We need busybox to embed into initramfs
RUN USE="static" emerge --quiet sys-apps/busybox
# We need cpio to pack initramfs
RUN emerge --quiet app-arch/cpio
# We need LVM to embed into initramfs
RUN USE="static static-libs" emerge --quiet dev-libs/boost
RUN USE="static static-libs" emerge --quiet dev-libs/expat
RUN FEATURES="-sandbox -usersandbox" USE="static static-libs" emerge --quiet sys-fs/lvm2
# # Cleanup
# RUN rm -rf /boot /var/db/* /var/cache/* /var/tmp/portage
# RUN find /var/log -type f -name '*.log' -exec rm {} \;

RUN rm -rf /boot

RUN echo -n "${KERNEL_VERSION}" > /kernel-version
# Copy kernel configuration
COPY docker/i686/kernel-builder/config-${KERNEL_VERSION}-gentoo /support/kernel/config-${KERNEL_VERSION}-gentoo
COPY docker/i686/kernel-builder/init.sh /support/initramfs/init
COPY docker/i686/kernel-builder/docker-entrypoint.sh /support/docker-entrypoint.sh

VOLUME [ "/data" ]

ENTRYPOINT [ "/support/docker-entrypoint.sh" ]
