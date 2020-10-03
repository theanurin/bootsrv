# Network Boot Server

This is a How To memo project that describes setup and configuration of a Gentoo server to be able to boot workstations inside your LAN.

The project contains some automation apps to setup a new workstation from a template (auto OS installation). Just plug-in a new workstation in your LAN, in few minutes it ready to use.

## Used software
* [Apache](https://httpd.apache.org/) - Web server for serve static files and execute CGI scripts
* [DHCP Server](https://www.isc.org/dhcp/) - Providers auto configuration your network (lease IP addresses)
* [Linux SCSI target framework (tgt)](http://stgt.sourceforge.net/) - Provides SAN-boot (boot Windows)
* [NFS Server](https://en.wikipedia.org/wiki/Network_File_System) - Provides network filesystem (NFS root, diskless Linux
  workstation)
* [TFTP Server](http://freshmeat.sourceforge.net/projects/tftp-hpa) - Providers ability to load kernel and initramfs via network for [PXE](https://en.wikipedia.org/wiki/Preboot_Execution_Environment). See [Wikipedia](https://en.wikipedia.org/wiki/Trivial_File_Transfer_Protocol) for protocol details.

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
	# c - example for net-misc/netifrc

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
1. IP Tables

	Set `SAVE_ON_STOP="no"` in `/etc/conf.d/iptables`

	Make rules config
	```
	# /var/lib/iptables/rules-save

	*nat
	:PREROUTING ACCEPT [0:0]
	:INPUT ACCEPT [0:0]
	:OUTPUT ACCEPT [0:0]
	:POSTROUTING ACCEPT [0:0]
	[0:0] -A POSTROUTING -j MASQUERADE
	COMMIT

	*mangle
	:PREROUTING ACCEPT [0:0]
	:INPUT ACCEPT [0:0]
	:FORWARD ACCEPT [0:0]
	:OUTPUT ACCEPT [0:0]
	:POSTROUTING ACCEPT [0:0]
	COMMIT

	*filter
	:INPUT ACCEPT [0:0]
	:FORWARD ACCEPT [0:0]
	:OUTPUT ACCEPT [0:0]
	COMMIT
	```

	```
	rc-update add iptables boot
	```
1. Router options

	Set inside `/etc/sysctl.conf`
	```
	net.ipv4.ip_forward = 1
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

	DHCPD_CONF=/etc/dhcp/dhcpd.conf
	DHCPD_IFACE="lan"
	DHCPD_OPTS="-4"
	```

	```
	# /etc/dhcp/dhcpd.conf
	#

	default-lease-time 3600;
	max-lease-time 7200;
	log-facility local5;
	ddns-update-style none;
	authoritative;

	subnet 192.168.254.0 netmask 255.255.255.0 {
		range 192.168.254.150 192.168.254.199;
		next-server 192.168.254.254;
		filename "ipxe/miner.undionly.kpxe";
		option routers 192.168.254.254;
		option broadcast-address 192.168.254.255;
		option subnet-mask 255.255.255.0;
		option domain-name-servers 192.168.254.254;
	}


	host 192.168.254.101.rig01 {
		hardware ethernet 70:85:c2:22:4d:fd;
		fixed-address 192.168.254.101;
	}

	host 192.168.254.102.rig02 {
		hardware ethernet 70:85:c2:25:0e:b4;
		fixed-address 192.168.254.102;
		filename "ipxe/rig02.undionly.kpxe";
	}

	host 192.168.254.034.PolinaPC {
		hardware ethernet 20:cf:30:8a:d3:7b;
		fixed-address 192.168.254.34;
		filename "pxelinux/pxelinux.0";
	}
	```

	```bash
	/etc/init.d/dhcpd start
	rc-update add dhcpd default
	```

1. Configure [TFTP Server](https://en.wikipedia.org/wiki/Trivial_File_Transfer_Protocol) for `lan` interface. Workstations start booting by download some files from the TFTP Server

	```
	# /etc/conf.d/in.tftpd
	# net-ftp/tftp-hpa-5.2-r1::gentoo

	INTFTPD_PATH="/srv/tftp/"
	INTFTPD_OPTS="--ipv4 --address 192.168.254.254 --port-range 4096:32767 --secure ${INTFTPD_PATH}"
	```

	```bash
	/etc/init.d/in.tftpd start
	rc-update add in.tftpd default
	```

1. Configure [NFS Server](https://en.wikipedia.org/wiki/Network_File_System) for `lan` interface. This allows to boot NFS-root basedd workstations

	```
	# /etc/conf.d/rpcbind

	RPCBIND_OPTS="-h 192.168.254.254"
	```

	```bash
	/etc/init.d/nfs start
	rc-update add nfs default
	```

	```
	# /etc/exports

	/srv/nfs/home/check 192.168.254.0/24(insecure,sync,rw,no_root_squash,no_subtree_check,no_all_squash)
	/srv/nfs/home/miner 192.168.254.0/24(insecure,sync,rw,no_root_squash,no_subtree_check,no_all_squash)
	/srv/nfs/opt        192.168.254.0/24(insecure,sync,ro,no_root_squash,subtree_check,no_all_squash)
	```

	```
	exportfs -ra
	```

1. Configure Apache2

	```
	rc-update add apache2 default
	```