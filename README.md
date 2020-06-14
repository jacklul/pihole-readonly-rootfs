# Pi-hole on read-only rootfs system

Running in read-only system mode prevents system files from being corrupted due to issues with SD card corruption.
My approach adds data partition (and optionally a second 'mirror' one for backup) where required directories and files will be stored.

- [Setting up](/01%20Read-only%20system.md)
- [Pi-hole](/02%20Pi-hole.md)
- DNS resolvers
	- [Unbound (recursive)](/02-1%20Unbound.md)
	- [DNSCrypt (DNS over HTTPS)](/02-2%20DNSCrypt.md)
	- [Cloudflared (DNS over HTTPS)](/02-3%20Cloudflared.md)

_Guides last updated: 14-06-2020_
