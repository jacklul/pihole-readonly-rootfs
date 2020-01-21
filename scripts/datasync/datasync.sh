#!/bin/bash
# This script synchronizes primary
# /data partition to the secondary one

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
	exec sudo -- "$0" "$@"
	exit
fi

LOCKFILE=/tmp/$(basename $0).lock
CONFIG_FILE=/etc/datasync.conf
DATA_MOUNTPOINT=/data
MIRROR_MOUNTPOINT=/mnt/datamirror

if [ -f "${CONFIG_FILE}" ]; then
	. ${CONFIG_FILE}
fi

if [ ! -f "$LOCKFILE" ]; then
	touch $LOCKFILE
else
	echo "Already running. (LOCKFILE: ${LOCKFILE})"
	exit 6
fi

function unmountMirror() {
	if mount | grep $MIRROR_MOUNTPOINT > /dev/null; then
		umount $MIRROR_MOUNTPOINT && rmdir $MIRROR_MOUNTPOINT
	fi
}

function onInterruptOrExit() {
	unmountMirror
	rm "$LOCKFILE" >/dev/null 2>&1
}
trap onInterruptOrExit EXIT

if ! mount | grep $DATA_MOUNTPOINT | grep '(rw' > /dev/null ; then
	echo "Data partition is not mounted or mounted read-only!"
	exit 1
fi

unmountMirror

CURRENT_DEV=`df -h | awk '$6 == "/data" {print $1}'`
echo "Current data device: ${CURRENT_DEV}"

if [ "$CURRENT_DEV" = "/dev/mmcblk0p3" ]; then
	mkdir -p $MIRROR_MOUNTPOINT && mount /dev/mmcblk0p4 $MIRROR_MOUNTPOINT
else
	mkdir -p $MIRROR_MOUNTPOINT && mount /dev/mmcblk0p3 $MIRROR_MOUNTPOINT
fi

if [ $? -ne 0 ]; then
	echo "Failed to mount data mirror"
	exit 1
fi

if [ ! -w "$MIRROR_MOUNTPOINT" ]; then
	echo "Data mirror is not writable"
	exit 1
fi

echo "Synchronizing..."

renice -n -20 $$ > /dev/null
rsync -aHAXSv --delete --inplace \
	--exclude={"${DATA_MOUNTPOINT}/lost+found"} \
	$DATA_MOUNTPOINT/ $MIRROR_MOUNTPOINT \

STATUS=$?
unmountMirror

if [ $STATUS == 24 ]; then
	STATUS=0
fi

if [ $STATUS == 0 ]; then
	echo "Finished successfully"
else
	echo "Finished with errors"
fi

exit $STATUS
