# Network Boot Server

This is a How To memo project that describes setup and configuration of a Gentoo server to be able to boot workstations inside your LAN.

The project contains some automation apps to setup a new workstation from a template (auto OS installation). Just plug-in a new workstation in your LAN, in few minutes it ready to use.

## Used software
* [OpenLDAP](https://www.openldap.org/) - Provides centralized configuration for your network, users, permissions, etc.
* [DHCP Server](https://www.isc.org/dhcp/) - Providers auto configuration your network (lease IP addresses)
* [Apache](https://httpd.apache.org/) - Web server for serve static files and execute CGI scripts
* [NFS Server](https://en.wikipedia.org/wiki/Network_File_System) - Provides network filesystem
* [TFTP Server](http://freshmeat.sourceforge.net/projects/tftp-hpa) - Providers ability to load kernel and initramfs via network for [PXE](https://en.wikipedia.org/wiki/Preboot_Execution_Environment). See [Wikipedia](https://en.wikipedia.org/wiki/Trivial_File_Transfer_Protocol) for protocol details.
* [Linux SCSI target framework (tgt)](http://stgt.sourceforge.net/) - Provides SAN-boot (boot Windows)

## How to use
### Setup
1. Prepare hardware. You may use any old PC with two network cards.
1. Setup Gentoo OS (this manual is tested on x86)
1. Setup network interface names:
	* wan - For internet connection
	* lan - For internal network (workstation's network)

	```
	# /etc/udev/rules.d/70-net-name-use-custom.rules - Renaming example via udev
	#
	# Change xx:xx:xx:xx:xx:xx for your MAC addresses
	#

	SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="xx:xx:xx:xx:xx:xx", NAME="wan"

	SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="xx:xx:xx:xx:xx:xx", NAME="lan"
	```
1. Setup IP configuration
	* `wan` - Your own choose like a DHCP Client, static IP, etc.
	* `lan` - Predefined IP/Network `192.168.254.254/24` (this IP is used inside all configuration files and CGI scripts)
	```
	# /etc/conf.d/net - example for net-misc/netifrc

	dns_domain_lo="localdomain"
	
	dns_servers_wan="8.8.8.8"
	config_wan="dhcp"

	config_lan="192.168.254.254 netmask 255.255.255.0"
	```
	```bash
	cd /etc/init.d/
	ln -s net.lo net.lan
	ln -s net.lo net.wan
	rc-update add net.lan boot
	rc-update add net.lo boot
	rc-update add net.wan boot
	```
1. Setup hostname
	```
	# /etc/conf.d/hostname
	hostname="bootsrv"
	```
	```
	# /etc/hosts
	127.0.0.1    bootsrv localhost
	::1          bootsrv localhost
	```
1. Reboot to apply IP configuration
1. Clone this repo into `/opt/bootsrv`
	```
	cd /opt && git clone https://github.com/theanurin/bootsrv.git
	```
1. Configure DHCP Server for `lan` interface. DHCP Server provides autoconfiguration for your workstation's network along with [BOOTP](https://en.wikipedia.org/wiki/Bootstrap_Protocol)

	```
	# /etc/conf.d/dhcpd
	# net-misc/dhcp-4.4.1::gentoo

	DHCPD_CONF=/opt/bootsrv/etc/dhcpd4.conf
	#DHCPD_CONF=/opt/bootsrv/etc/dhcpd4-ldap.conf
	DHCPD_IFACE="lan"
	DHCPD_OPTS="-4"
	```

	```bash
	/etc/init.d/dhcpd start
	rc-update add dhcpd default
	```

1. Configure [TFTP Server](https://en.wikipedia.org/wiki/Trivial_File_Transfer_Protocol) for `lan` interface. Workstations start booting by download some files from the TFTP Server

	```
	# /etc/conf.d/in.tftpd
	# net-ftp/tftp-hpa-5.2-r1::gentoo

	INTFTPD_OPTS="--ipv4 --address 192.168.254.254 --port-range 4096:32767 --secure /opt/bootsrv/tftp/"
	```

	```bash
	/etc/init.d/in.tftpd start
	rc-update add in.tftpd default
	```

