#!/bin/bash

[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

set -e
command -v rsync >/dev/null 2>&1 || { echo "This script requires rsync to run, install it with 'sudo apt install rsync'."; exit 1; }

if [ ! -b "/dev/mmcblk0p3" ]; then
	echo "Could not find block device for data partition."
	echo "Make sure /dev/mmcblk0p3 is available."
	exit 1
fi

SPATH=$(dirname $0)
REMOTE_URL=https://raw.githubusercontent.com/jacklul/pihole-readonly-rootfs/master/scripts/databackup

if [ -f "$SPATH/databackup.sh" ] && [ -f "$SPATH/databackup.service" ] && [ -f "$SPATH/databackup.timer" ]; then
	cp -v $SPATH/databackup.sh /usr/local/sbin/databackup && chmod +x /usr/local/sbin/databackup
	
	if [ ! -f "/etc/databackup.conf" ]; then
		cp -v $SPATH/databackup.conf /etc/databackup.conf
	fi
	
	cp -v $SPATH/databackup.service /etc/systemd/system && chmod 644 /etc/systemd/system/databackup.service
	cp -v $SPATH/databackup.timer /etc/systemd/system && chmod 644 /etc/systemd/system/databackup.timer
elif [ "$REMOTE_URL" != "" ]; then
	wget -nv -O /usr/local/sbin/databackup "$REMOTE_URL/databackup.sh" && chmod +x /usr/local/sbin/databackup
	
	if [ ! -f "/etc/databackup.conf" ]; then
		wget -nv -O /etc/databackup.conf "$REMOTE_URL/databackup.conf"
	fi
	
	wget -nv -O /etc/systemd/system/databackup.service "$REMOTE_URL/databackup.service" && chmod 644 /etc/systemd/system/databackup.service
	wget -nv -O /etc/systemd/system/databackup.timer "$REMOTE_URL/databackup.timer" && chmod 644 /etc/systemd/system/databackup.timer
else
	exit 1
fi

echo "Enabling and starting databackup.timer..."
systemctl enable databackup.timer && systemctl start databackup.timer
