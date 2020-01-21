# DNSCrypt (DNS over HTTPS using Cloudflare)

_Refer to https://github.com/pi-hole/pi-hole/wiki/DNSCrypt-2.0 for more information._

## Installation

```bash
sudo apt install dnscrypt-proxy
```

## For read only filesystem:

```bash
sudo mkdir -p /data/etc
sudo mkdir -p /data/var/cache
sudo mkdir -p /var/cache/dnscrypt-proxy

sudo cp -a /etc/dnscrypt-proxy /data/etc
sudo cp -a /var/cache/dnscrypt-proxy /data/var/cache
```

```bash
sudo nano /etc/fstab
```
```
# DNSCrypt
/data/etc/dnscrypt-proxy        /etc/dnscrypt-proxy        none  bind,nofail  0 0
/data/var/cache/dnscrypt-proxy  /var/cache/dnscrypt-proxy  none  bind,nofail  0 0
```

```bash
sudo mount -a
```

## Configuration

```bash
sudo nano /etc/dnscrypt-proxy/dnscrypt-proxy.toml
```

```
## List of servers to use
## https://dnscrypt.info/public-servers
server_names = ['cloudflare']

## List of local addresses and ports to listen to. Can be IPv4 and/or IPv6.
listen_addresses = ['127.0.0.1:5053']

## Switch to a different system user after listening sockets have been created.
user_name = '_dnscrypt-proxy'

## Maximum number of simultaneous client connections to accept
max_clients = 200

# Use servers reachable over IPv4
ipv4_servers = true

# Use servers reachable over IPv6 -- Do not enable if you don't have IPv6 connectivity
ipv6_servers = false

# Use servers implementing the DNSCrypt protocol
dnscrypt_servers = true

# Use servers implementing the DNS-over-HTTPS protocol
doh_servers = true

# Server must support DNS security extensions (DNSSEC)
require_dnssec = true

# Server must not log user queries (declarative)
require_nolog = true

# Server must not enforce its own blacklist (for parental control, ads blocking...)
require_nofilter = true

## Always use TCP to connect to upstream servers.
force_tcp = false

## How long a DNS query will wait for a response, in milliseconds.
timeout = 2500

## Keepalive for HTTP (HTTPS, HTTP/2) queries, in seconds
keepalive = 30

## Delay, in minutes, after which certificates are reloaded
cert_refresh_delay = 240

## DNSCrypt: Create a new, unique key for every single DNS query
dnscrypt_ephemeral_keys = true

## DoH: Use a specific cipher suite instead of the server preference
tls_cipher_suite = [49195, 49199]

## Fallback resolver
## This is a normal, non-encrypted DNS resolver, that will be only used
## for one-shot queries when retrieving the initial resolvers list, and
## only if the system DNS configuration doesn't work.
fallback_resolver = '1.1.1.1:53'

## Always use the fallback resolver before the system DNS settings
ignore_system_dns = true

## Address and port to try initializing a connection to, just to check
## if the network is up. It can be any address and any port, even if
## there is nothing answering these on the other side.
netprobe_address = '1.1.1.1:53'

## Maximum time (in seconds) to wait for network connectivity before
## initializing the proxy.
netprobe_timeout = 30

## Immediately respond to IPv6-related queries with an empty response
block_ipv6 = false

## Enable a DNS cache to reduce latency and outgoing traffic
cache = true

[sources]
  ## An example of a remote source from https://github.com/DNSCrypt/dnscrypt-resolvers

  [sources.'public-resolvers']
  urls = ['https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v2/public-resolvers.md', 'https://download.dnscrypt.info/resolvers-list/v2/public-resolvers.md']
  cache_file = '/var/cache/dnscrypt-proxy/public-resolvers.md'
  minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
  refresh_delay = 72
  prefix = ''
```
[Configuration file reference](https://github.com/DNSCrypt/dnscrypt-proxy/blob/master/dnscrypt-proxy/example-dnscrypt-proxy.toml)

```bash
sudo systemctl stop dnscrypt-proxy-resolvconf.service
sudo systemctl stop dnscrypt-proxy.socket
sudo systemctl stop dnscrypt-proxy.service

sudo systemctl disable dnscrypt-proxy-resolvconf.service
sudo systemctl disable dnscrypt-proxy.socket
sudo systemctl disable dnscrypt-proxy.service

cd /etc/dnscrypt-proxy/
sudo dnscrypt-proxy -service install
sudo systemctl start dnscrypt-proxy.service
sudo systemctl enable dnscrypt-proxy.service
```

```bash
dig @127.0.0.1 -p 5053 google.com
```
