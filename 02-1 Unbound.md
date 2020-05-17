# Unbound (recursive DNS resolver)

_Refer to https://docs.pi-hole.net/guides/unbound/ for more information._

## Installation

```bash
sudo apt install unbound
```

```bash
sudo nano /etc/systemd/system/unbound-roothints.service
```
```
[Unit]
Description=Update root hints for unbound
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache 
ExecStartPost=chown unbound:unbound /var/lib/unbound/root.hints
```

```bash
sudo nano /etc/systemd/system/unbound-roothints.timer
```
```
[Unit]
Description=Monthly update of root hints for unbound
After=datasync.timer

[Timer]
OnCalendar=monthly
Persistent=true
 
[Install]
WantedBy=timers.target
```

```bash
sudo systemctl start unbound-roothints.timer
sudo systemctl enable unbound-roothints.timer
sudo systemctl start unbound-roothints.service
```

## For read only filesystem

Only when [followed this](/01%20Read-only%20system.md)!

```bash
sudo mkdir -p /data/etc
sudo mkdir -p /data/var/lib

sudo cp -a /etc/unbound /data/etc
sudo cp -a /var/lib/unbound/ /data/var/lib
```

```bash
sudo nano /etc/fstab
```
```
# Unbound
/data/etc/unbound        /etc/unbound        none  bind,nofail  0 0
/data/var/lib/unbound    /var/lib/unbound    none  bind,nofail  0 0
```

```bash
sudo mount -a
```

## Configuration

This is slightly modified config provided on [Pi-hole's website](https://docs.pi-hole.net/guides/unbound/).

```bash
sudo nano /etc/unbound/unbound.conf.d/pi-hole.conf
```
```
server:
	# Log only essentials
	verbosity: 1

	# If no logfile is specified, syslog is used
	logfile: "/var/log/unbound.log"

	# Listen only on local address
	interface: 127.0.0.1

	# Server port
	port: 5053

	# Enable or disable whether specific queries are answered or issued.
	do-ip4: yes
	do-ip6: yes
	do-udp: yes
	do-tcp: yes

	# Use this only when you downloaded the list of primary root servers!
	root-hints: "/var/lib/unbound/root.hints"

	# One thread should be sufficient, can be increased on beefy machines.
	# In reality for most users running on small networks or on a single machine it should be unnecessary to seek performance enhancement by increasing num-threads above 1.
	num-threads: 1

	# Minimum and maximum TTL to keep messages in the cache
	cache-min-ttl: 300
	cache-max-ttl: 86400

	# Number of bytes size to advertise as the EDNS reassembly buffer size
	edns-buffer-size: 1472

	# Ensure kernel buffer is large enough to not lose messages in traffic spikes
	so-rcvbuf: 1m

	# Allow only access from the local machine
	access-control: 127.0.0.1/32 allow

	# Ensure privacy of local IP ranges
	private-address: 192.168.0.0/16
	private-address: 169.254.0.0/16
	private-address: 172.16.0.0/12
	private-address: 10.0.0.0/8
	private-address: fd00::/8
	private-address: fe80::/10
	
	# Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
	harden-dnssec-stripped: yes

	# Trust glue only if it is within the server's authority
	harden-glue: yes

	# Refuses version and hostname queries
	hide-identity: yes
	hide-version: yes

	# Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
	# see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
	use-caps-for-id: no

	# Cache elements are prefetched before they expire to keep the cache up to date
	prefetch: yes

	# Fetch the DNSKEYs earlier in the validation process
	prefetch-key: yes

```
[Configuration file reference](https://nlnetlabs.nl/documentation/unbound/unbound.conf/)

```bash
sudo systemctl start unbound
sudo systemctl enable unbound
```

```bash
dig @127.0.0.1 -p 5053 google.com
```
