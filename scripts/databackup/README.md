# Synchronize data partition to backup location

This script synchronizes first data partition to the backup location.
It assumes that devices `/dev/mmcblk0p3` is the data partition.

### Install

```bash
wget -O - https://raw.githubusercontent.com/jacklul/pihole-readonly-rootfs/master/scripts/databackup/install.sh | sudo bash
```

Set the backup destination directory in `/etc/databackup.conf` file.
(`/home/pi/databackup` by default)
