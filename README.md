# Pi-hole on read-only rootfs system (Raspberry Pi)

Running in read-only system mode prevents system files from being corrupted due to issues with SD card corruption.
My approach adds data partition where directories and files that need to be writable will be stored.
This significantly reduces the risk of bricking your project.

- [Setting up](/01%20Read-only%20system.md)
- [Pi-hole](/02%20Pi-hole.md)
- DNS resolvers
	- [Unbound (recursive)](/02-1%20Unbound.md)
	- [DNSCrypt (DNS over HTTPS)](/02-2%20DNSCrypt.md)
	- [Cloudflared (DNS over HTTPS)](/02-3%20Cloudflared.md)

_Guides last updated: 09-04-2023_  
_Supports Raspberry Pi OS: Buster, Bullseye_
