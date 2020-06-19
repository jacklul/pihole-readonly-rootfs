# Pi-hole on read-only system mode

**This assumes system is already set up as read-only.**

Install Pi-hole normally - `wget -O - https://install.pi-hole.net | sudo bash`, configure it the way you want it (make the system writable with `rw` command before installing, obviously).

Optionally you might want to set `DBINTERVAL` in `/etc/pihole/pihole-FTL.conf` to something bigger than default `1 minute` (5 minutes should be good).

## Setting up

First, stop Pi-hole services:
```bash
sudo systemctl stop pihole-FTL.service
sudo systemctl stop lighttpd.service
```

Move required stuff to data partition:
```bash
sudo mkdir -p /data/etc
sudo mkdir -p /data/var/cache

sudo cp -a /etc/pihole /data/etc
sudo cp -a /etc/dnsmasq.d /data/etc
sudo cp -a /etc/lighttpd /data/etc
sudo cp -a /var/lib/php /data/var/lib
sudo cp -a /var/cache/lighttpd /data/var/cache
```

Add directory binds to `/etc/fstab`:
```
# Pi-hole
/data/etc/pihole          /etc/pihole          none  bind,nofail  0 0
/data/etc/dnsmasq.d       /etc/dnsmasq.d       none  bind,nofail  0 0
/data/etc/lighttpd        /etc/lighttpd        none  bind,nofail  0 0
/data/var/lib/php         /var/lib/php         none  bind,nofail  0 0
/data/var/cache/lighttpd  /var/cache/lighttpd  none  bind,nofail  0 0
```

Apply changes - `sudo mount -a`.

### Fixing Pi-hole starting as root

Properties cannot be set on read-only filesystem so we have to apply a small workaround by copying the executable to suitable place and then binding original one to it.

Create following scripts:

```bash
sudo nano /opt/pihole/beforestart.sh
```
```
#!/bin/bash

if ! mount | grep /usr/bin/pihole-FTL > /dev/null && [ $(mount | sed -n -e "s/^\/dev\/.* on \/ .*(\(r[w|o]\).*/\1/p") = "ro" ]; then
        echo "Read only rootfs detected, copying and binding pihole-FTL binary..."

        mkdir -p /mnt/pihole-FTL && mount tmpfs -t tmpfs /mnt/pihole-FTL
        cp -fpv /usr/bin/pihole-FTL /mnt/pihole-FTL && mount -v -o bind /mnt/pihole-FTL/pihole-FTL /usr/bin/pihole-FTL
fi
```

```bash
sudo nano /opt/pihole/afterstop.sh
```
```
#!/bin/bash

if mount | grep /usr/bin/pihole-FTL > /dev/null; then
        umount -v /usr/bin/pihole-FTL
fi

if mount | grep /mnt/pihole-FTL > /dev/null; then
        umount -v /mnt/pihole-FTL && rmdir /mnt/pihole-FTL
fi
```

Make them executable:
```bash
sudo chmod +x /opt/pihole/beforestart.sh
sudo chmod +x /opt/pihole/afterstop.sh
```

Add them to `pihole-FTL` service:

```bash
sudo systemctl edit pihole-FTL.service
```
```
[Service]
ExecStartPre=+/opt/pihole/beforestart.sh
ExecStop=+/opt/pihole/afterstop.sh
```

Now we can start Pi-hole:
```bash
sudo systemctl start lighttpd.service
sudo systemctl start pihole-FTL.service
```

## Optional: DNS resolvers

For security and/or privacy you should set up a local resolver.

Common configurations:
- [Unbound](/02-1%20Unbound.md) (recursive)
- [DNSCrypt](/02-2%20DNSCrypt.md) (DNS over HTTPS using Cloudflare)
- [Cloudflared](/02-3%20Cloudflared.md) (DNS over HTTPS using Cloudflare)

You should install [Unbound](/02-1%20Unbound.md) in most cases.
