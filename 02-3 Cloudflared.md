# Cloudflared (DNS over HTTPS using Cloudflare)

_Refer to https://docs.pi-hole.net/guides/dns-over-https/ for more information._

## Installation

```bash
wget https://bin.equinox.io/c/VdrWdbjqyF/cloudflared-stable-linux-arm.tgz
tar -xvzf cloudflared-stable-linux-arm.tgz
sudo cp ./cloudflared /usr/local/bin
sudo chmod +x /usr/local/bin/cloudflared
cloudflared -v
```

*WARNING* Raspberry Pi 1 and Zero are armv6 and require either compiling `cloudflared` manually or using older build:

```bash
wget https://bin.equinox.io/a/4SUTAEmvqzB/cloudflared-2018.7.2-linux-arm.tar.gz
tar -xvzf cloudflared-2018.7.2-linux-arm.tar.gz
sudo cp ./cloudflared /usr/local/bin
sudo chmod +x /usr/local/bin/cloudflared
cloudflared -v
```

## For read only filesystem

Only when [followed this](/01%20Read-only%20system.md)!

```bash
sudo mkdir -p /data/etc

sudo cp -a /etc/cloudflared /data/etc/cloudflared
```

```bash
sudo nano /etc/fstab
```
```
# Cloudflared
/data/etc/cloudflared  /etc/cloudflared  none  bind,nofail  0 0
```

```bash
sudo mount -a
```

## Configuration

```bash
sudo nano /etc/cloudflared/config.yaml
```
```
proxy-dns: true
proxy-dns-address: "127.0.0.1"
# proxy-dns-address: "::1"
proxy-dns-port: 5053
proxy-dns-upstream:
 - https://1.1.1.1/dns-query
 - https://1.0.0.1/dns-query
```
[Configuration file reference](https://developers.cloudflare.com/argo-tunnel/reference/config/)

```bash
sudo useradd -s /usr/sbin/nologin -r -M cloudflared
sudo chown -R cloudflared:cloudflared /etc/cloudflared
```

```bash
sudo nano /etc/systemd/system/cloudflared.service
```

```
[Unit]
Description=Cloudflared DNS over HTTPS proxy
After=syslog.target network-online.target

[Service]
Type=simple
User=cloudflared
ExecStart=/usr/local/bin/cloudflared
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

```bash
dig @127.0.0.1 -p 5053 google.com
```
