# How to build this stuff

The project includes:
* Gentoo Kernel
* Gentoo OS


## Gentoo Kernel

### Build inside Docker

```bash
# See https://packages.gentoo.org/packages/sys-kernel/gentoo-sources
#export KERNEL_VERSION=4.19.113
export KERNEL_VERSION=5.4.28
export ARCH=i686
#export ARCH=amd64
docker build --tag bootsrv-kernel --file docker/${ARCH}/Dockerfile --build-arg KERNEL_VERSION . && \
  docker run --privileged --rm --interactive --tty --volume ${PWD}/.data:/data bootsrv-kernel
```
TS=$(date '+%Y%m%d%H%M%S') && { VBoxManage convertfromraw --format VDI .data/everyboot.img .data/everyboot-$TS.vdi && VBoxManage modifyhd .data/everyboot-$TS.vdi --resize 8912 }

## Dev cycles

```bash
# See https://packages.gentoo.org/packages/sys-kernel/gentoo-sources
#export KERNEL_VERSION=4.19.113
export KERNEL_VERSION=5.4.28
export ARCH=i686
```

### Kernel
Configure

```bash
docker build --tag bootsrv-kernel --file docker/${ARCH}/Dockerfile --build-arg KERNEL_VERSION . && docker run --rm --interactive --tty --volume ${PWD}/.data:/data bootsrv-kernel config
```

Build

```bash
docker build --tag bootsrv-kernel --file docker/${ARCH}/Dockerfile --build-arg KERNEL_VERSION . && docker run --rm --interactive --tty --volume ${PWD}/.data:/data bootsrv-kernel kernel
```

### Initramfs

```bash
rm -rf .data/.initramfs .data/initramfs; sleep 3; docker build --tag bootsrv-kernel --file docker/${ARCH}/Dockerfile --build-arg KERNEL_VERSION . && docker run --rm --interactive --tty --volume ${PWD}/.data:/data bootsrv-kernel initramfs
```

### Image

Note: Container required `--privileged` flag to manipulate loop devices while creating disk image.

```bash
rm .data/everyboot*; docker build --tag bootsrv-kernel --file docker/${ARCH}/Dockerfile --build-arg KERNEL_VERSION . && docker run --privileged --rm --interactive --tty --volume ${PWD}/.data:/data bootsrv-kernel image
```

### Virtual Box'es VDI

```bash
TS=$(date '+%Y%m%d%H%M%S'); VBoxManage convertfromraw --format VDI .data/everyboot.img .data/everyboot-$TS.vdi && VBoxManage modifyhd .data/everyboot-$TS.vdi --resize 8912
```