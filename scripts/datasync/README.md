# Synchronize data partition to its mirror

This script synchronizes first data partition to the second one.
It assumes that devices `/dev/mmcblk0p3` and `/dev/mmcblk0p4` are the data partitions.

### Install

```bash
wget -q -O - https://raw.githubusercontent.com/jacklul/pihole-readonly-rootfs/master/scripts/datasync/install.sh | sudo bash
```
