#!/bin/bash
# This script (un)mounts rootfs as /mnt/rootfs skipping all bind mounts

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
	exec sudo -- "$0" "$@"
	exit
fi

if ! mount | grep /mnt/rootfs > /dev/null; then
	mkdir -p /mnt/rootfs && mount --bind / /mnt/rootfs && echo "Mounted om /mnt/rootfs"
else
	umount /mnt/rootfs && rmdir /mnt/rootfs && echo "Unmounted /mnt/rootfs"
fi
