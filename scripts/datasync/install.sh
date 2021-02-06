#!/bin/bash

[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

set -e
command -v rsync >/dev/null 2>&1 || { echo "This script requires rsync to run, install it with 'sudo apt install rsync'."; exit 1; }

if [ ! -b "/dev/mmcblk0p3" ] && [ ! -b "/dev/mmcblk0p4" ]; then
	echo "Could not find block devices for data partitions."
	echo "Make sure /dev/mmcblk0p3 and /dev/mmcblk0p4 are available."
	exit 1
fi

SPATH=$(dirname $0)
REMOTE_URL=https://raw.githubusercontent.com/jacklul/pihole-readonly-rootfs/master/scripts/datasync/

if [ -f "$SPATH/datasync.sh" ] && [ -f "$SPATH/datasync.service" ] && [ -f "$SPATH/datasync.timer" ]; then
	cp -v $SPATH/datasync.sh /usr/local/sbin/datasync && chmod +x /usr/local/sbin/datasync
	cp -v $SPATH/datasync.service /etc/systemd/system && chmod 644 /etc/systemd/system/datasync.service
	cp -v $SPATH/datasync.timer /etc/systemd/system && chmod 644 /etc/systemd/system/datasync.timer
elif [ "$REMOTE_URL" != "" ]; then
	wget -nv -O /usr/local/sbin/datasync "$REMOTE_URL/datasync.sh" && chmod +x /usr/local/sbin/datasync
	wget -nv -O /etc/systemd/system/datasync.service "$REMOTE_URL/datasync.service" && chmod 644 /etc/systemd/system/datasync.service
	wget -nv -O /etc/systemd/system/datasync.timer "$REMOTE_URL/datasync.timer" && chmod 644 /etc/systemd/system/datasync.timer
else
	exit 1
fi

echo "Enabling and starting datasync.timer..."
systemctl enable datasync.timer && systemctl start datasync.timer
