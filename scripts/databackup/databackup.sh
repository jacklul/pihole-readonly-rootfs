#!/bin/bash
# This script synchronizes primary
# /data partition to backup location

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
	exec sudo -- "$0" "$@"
	exit
fi

LOCKFILE=/var/lock/$(basename $0)
CONFIG_FILE=/etc/databackup.conf
DATA_MOUNTPOINT=/data
BACKUP_DESTINATION=/home/pi/databackup
BACKUP_MOUNT=
EXCLUDE_FILE=/etc/databackup-ignore.list

if [ -f "${CONFIG_FILE}" ]; then
	. ${CONFIG_FILE}
fi

PID=$(cat ${LOCKFILE} 2> /dev/null || echo '')
if [ -e ${LOCKFILE} ] && [ ! -z "$PID" ] && kill -0 $PID; then
    echo "Script is already running!"
    exit 6
fi

echo $$ > ${LOCKFILE}

function unmountDestination() {
	if [ ! -z "$BACKUP_MOUNT" ] && mount | grep $BACKUP_MOUNT > /dev/null; then
		echo "Unmounting ${BACKUP_MOUNT}..."
		umount $BACKUP_MOUNT && rmdir $BACKUP_MOUNT
	fi
}

function onInterruptOrExit() {
	unmountDestination
	rm "$LOCKFILE" >/dev/null 2>&1
}
trap onInterruptOrExit EXIT

function mountDestination() {
	if [ ! -z "$BACKUP_MOUNT" ] && ! mount | grep $BACKUP_MOUNT > /dev/null; then
		echo "Mounting ${BACKUP_MOUNT}..."
		mkdir -p $BACKUP_MOUNT && mount $BACKUP_MOUNT
	fi
}

if ! mount | grep $DATA_MOUNTPOINT | grep '(rw' > /dev/null ; then
	echo "Data partition is not mounted or mounted read-only!"
	exit 1
fi

mountDestination

[ -f "$EXCLUDE_FILE" ] || { touch $EXCLUDE_FILE }

echo "Synchronizing to ${BACKUP_DESTINATION}..."

renice -n -20 $$ > /dev/null
rsync -aHAXSv --delete --inplace \
	--exclude={"${DATA_MOUNTPOINT}/lost+found"} \
	--exclude-from="$EXCLUDE_FILE" \
	$DATA_MOUNTPOINT/ $BACKUP_DESTINATION \

STATUS=$?
unmountDestination

if [ $STATUS == 24 ]; then
	STATUS=0
fi

if [ $STATUS == 0 ]; then
	echo "Finished successfully"
else
	echo "Finished with errors"
fi

exit $STATUS
