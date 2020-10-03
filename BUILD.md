# How to build this stuff

The project includes:
* Gentoo Kernel
* Gentoo OS


## Gentoo Kernel

### Build inside Docker

```bash
export KERNEL_VERSION=4.19.97
export ARCH=i686
#export ARCH=amd64
docker build --tag bootsrv-kernel --file docker/${ARCH}/kernel-builder/Dockerfile --build-arg KERNEL_VERSION . && \
  docker run --rm --interactive --tty --volume ${PWD}/.data:/data bootsrv-kernel
```