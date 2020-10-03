# Underhood

## Included software (/var/lib/portage/world)
```
app-admin/sudo
app-admin/syslog-ng
app-arch/cpio
app-editors/nano
app-misc/mc
app-misc/screen
app-portage/cpuid2cpuflags
app-portage/gentoolkit
net-dns/bind-tools
net-fs/nfs-utils
net-ftp/tftp-hpa
net-misc/dhcp
net-misc/dhcpcd
net-misc/ntp
sys-apps/ethtool
sys-apps/pciutils
sys-block/tgt
sys-boot/syslinux
sys-fs/lvm2
sys-fs/multipath-tools
sys-kernel/gentoo-sources
sys-process/cronie
sys-process/htop
www-servers/apache
```

## System configuration


### /etc/portage/make.conf
```
USE=""

APACHE2_MODULES="cgi"
```

### /etc/portage/package.use
```
www-servers/apache              -ssl
```

