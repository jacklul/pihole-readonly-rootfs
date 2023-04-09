# Raspberry Pi - read-only system

**This method is only for headless projects, it is assumed desktop features will not be used.**

We create additional writable data partition(s) that will contain required directories and files for the system to work correctly.

Procedure tested on Raspbian Buster and Bullseye Lite + Raspberry Pi Zero W

## Initial setup

Standard first time setup tasks:

- set up network - WiFi (or Ethernet dongle)
- `sudo raspi-config` tasks (hostname, timezone etc.)
- set up NTP servers in `/etc/systemd/timesyncd.conf` (executing `sudo timedatectl set-ntp 1` after might be required)
- `sudo apt update && sudo apt upgrade -y`
- enabling password protected sudo for the 'pi' user (replace `NOPASSWD` with `PASSWD` in `/etc/sudoers.d/010_pi-nopasswd`)
- enabling kernel panic reboot (`sudo sh -c 'echo "kernel.panic = 10" > /etc/sysctl.conf'`)

**If your Pi will be exposed to the public you should either disable or remove default `pi` user and create a new admin account.**

I recommend to use SSH keys and disable password authentication:
```bash
mkdir ~/.ssh
touch ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

echo "ssh-rsa ..." >> ~/.ssh/authorized_keys
```

Verify that you can login into the server using your key and then disable password authentication by setting `PasswordAuthentication no` in `/etc/ssh/sshd_config` and then restart SSH server:
```bash
sudo systemctl restart sshd.service
```

## Re-partitioning

System auto-expanded filesystem on first boot to fill the SD card - we don't want that - shutdown the Pi (`sudo shutdown -r now`), take the SD card out and insert it into computer's card reader for repartitioning.
Shrink rootfs partition to reasonable size (around 4-6GB should be fine for simple projects) and create a data partition (preferably at the end of the SD card).

This is how it looks like in case of my 16GB card:

| device         | fs    | label  | size   |
|----------------|-------|--------|--------|
| /dev/sda1      | fat32 | boot   | 256MB  |
| /dev/sda2      | ext4  | rootfs | 6GB    |
| - free space - |       |        | ~0.5GB |
| /dev/sda3      | ext4  | data   | 8GB    |

Now you can put the card back into the Pi and boot it.

If you're really worried about data partition getting corrupted you could create two of them and keep them in sync them with [this script](/scripts/datasync/) but this will increase the wear on the SD card (make sure they are `/dev/sda3` and `/dev/sda4` respectively).
Good solution is to backup the data partition periodically - for example through [rclone-backup](https://github.com/jacklul/rclone-backup).

## Preparations

Tweak boot configuration:
```bash
sudo nano /boot/config.txt
```
```
# Reduce memory reserved for GPU
gpu_mem=16

# Blink LED on activity, otherwise keep it off
dtparam=act_led_activelow=off
dtparam=act_led_trigger=actpwr

# Disable audio, unless you're going to use it
dtparam=audio=off

# Disable Bluetooth, unless you're going to use it
dtoverlay=disable-bt

# Disable WiFi, unless you're going to use it
dtoverlay=disable-wifi

# Enable hardware watchdog, automatic reboots when device hangs
dtparam=watchdog=on
```

Disable HDMI on boot: 
```bash
sudo nano /etc/rc.local
```
```
# Disable HDMI port
/opt/vc/bin/tvservice -o # For Buster
/usr/bin/tvservice -o # For Bullseye

exit 0
```

Configure watchdog:
```bash
sudo nano /etc/systemd/system.conf
```
```
RuntimeWatchdogSec=15
RebootWatchdogSec=5min
ShutdownWatchdogSec=5min
```

Disable SWAP:
```bash
sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall
sudo systemctl disable dphys-swapfile.service
```
_You can re-enable it later and reconfigure it to use the `/data` partition._

Other stuff to disable:

```bash
# Not needed on headless system
sudo systemctl disable triggerhappy.service
sudo systemctl disable console-setup.service

# No point for these to run since APT can't run on read-only filesystem
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily.service
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable apt-daily-upgrade.service
```

## Setting up the read-only mode

Check the permissions of the directories we are about to move to `tmpfs`:
```bash
stat -c "%a %U %G %n" /mnt /var/log /var/mail /var/spool/rsyslog /tmp /var/lib/logrotate
```

Edit `/etc/fstab` (`PARTUUID` might be different - adjust accordingly):
```
proc                  /proc  proc  defaults                   0 0
PARTUUID=6c586e13-01  /boot  vfat  ro                         0 2
PARTUUID=6c586e13-02  /      ext4  noatime,ro                 0 1
PARTUUID=6c586e13-03  /data  ext4  noatime,errors=remount-ro  0 2

# RAMdisk
tmpfs  /mnt                tmpfs  nosuid,nodev,noexec,noatime,mode=0755,size=1M            0 0
tmpfs  /var/lib/logrotate  tmpfs  nosuid,nodev,noexec,relatime,mode=0755,size=100K         0 0
tmpfs  /var/log            tmpfs  nosuid,nodev,noexec,relatime,mode=0755,size=50M          0 0
tmpfs  /var/mail           tmpfs  nosuid,nodev,noexec,relatime,mode=2775,gid=mail,size=1M  0 0
tmpfs  /var/spool/rsyslog  tmpfs  nosuid,nodev,noexec,relatime,mode=0700,size=1M           0 0
tmpfs  /tmp                tmpfs  nosuid,nodev,noexec,relatime,mode=1777,size=50%          0 0

# Optional: system/apps might expect stuff here to survive the reboot process
#/tmp   /var/tmp            none   bind                                                     0 0
```

_You can increase /tmp size as you wish - I recommend setting it to max 50% of total RAM_

Adjust the mounts permissions to match the output of the `stat` command from earlier!

I include `noexec` for the added security but some stuff might not work with it properly on the `/tmp` and `/var/tmp` mounts, one known is APT install/upgrade process but you can workaround it by doing this:

```bash
sudo nano /etc/apt/apt.conf.d/50remount
```
```
DPkg::Pre-Install-Pkgs {"/bin/mount -o remount,exec /tmp";};
DPkg::Post-Invoke {"/bin/mount -o remount /tmp";};
```

---
### If you're not going to be using static IP:

<details>
  <summary><b>Show instructions</b></summary>

You will also want to add these to the `/etc/fstab`:
```
# This *might* be not required
tmpfs  /var/lib/dhcp     tmpfs  nosuid,nodev,noexec,relatime,mode=0755,size=100K  0 0

# For Buster
tmpfs  /var/lib/dhcpcd5  tmpfs  nosuid,nodev,noexec,relatime,mode=0755,size=100K  0 0

# For Bullseye
tmpfs  /var/lib/dhcpcd  tmpfs  nosuid,nodev,noexec,relatime,mode=0755,size=100K  0 0
```

Because `duid` will be generated after each boot the IPv6 address will not be stable so we have to fallback to the `hwaddr` option:
```bash
sudo nano /etc/dhcpcd.conf
```
```
# Generate SLAAC address using the Hardware Address of the interface
slaac hwaddr
# OR generate Stable Private IPv6 Addresses based from the DUID
#slaac private
```
</details>

---

Remount everything with `sudo mount -a`. 

To continue, we need the system to be writable so:
```bash
sudo mount -o remount,rw /
sudo mount -o remount,rw /boot
```

We need to move some directories to the writable partition.

First, check their permissions:
```bash
stat -c "%a %U %G %n" /etc/ /home /var/ /var/lib/ /var/cache/ /etc/fake-hwclock.data /var/lib/systemd /var/tmp/
```

Now create/move them:
```bash
sudo mkdir -p /data/etc/ -m 755
sudo cp -ax /home /data
sudo mkdir -p /data/var/ -m 755
sudo mkdir -p /data/var/lib -m 755
sudo mkdir -p /data/var/cache -m 755
sudo cp -ax /etc/fake-hwclock.data  /data/etc
sudo cp -ax /var/lib/systemd /data/var/lib
sudo cp -ax /var/tmp /data/var
```
_Adjust these to match the output of the `stat` command from earlier!_

Verify that the permissions match the previous `stat` command output:
```bash
stat -c "%a %U %G %n" /data/etc /data/home /data/var /data/var/lib /data/var/cache /data/etc/fake-hwclock.data /data/var/lib/systemd /data/var/tmp
```

And add binds to `/etc/fstab`:
```
# Binds for read-only filesystem
/data/etc/fake-hwclock.data  /etc/fake-hwclock.data  none  bind  0 0
/data/home                   /home                   none  bind  0 0
/data/var/backups            /var/backups            none  bind  0 0
/data/var/lib/systemd        /var/lib/systemd        none  bind  0 0
# If you moved /var/tmp to tmpfs comment this
/data/var/tmp                /var/tmp                none  bind  0 0
```

Apply changes - `sudo mount -a`.

You will need to run these again:
```bash
sudo mount -o remount,rw /
sudo mount -o remount,rw /boot
```

Becase `fake-hwclock` is not able to access `/data/etc/fake-hwclock.data` in early boot stage the clock will be stuck too far into the past and `fsck` might force filesystem check which will delay the boot significantly, to fix this:
```bash
sudo systemctl edit fake-hwclock.service
```
```
[Service]
Environment="FILE=/run/fake-hwclock.data"
ExecStartPre=-/bin/sh -c "debugfs -R \"cat /etc/fake-hwclock.data\" /dev/mmcblk0p3 2>/dev/null > /run/fake-hwclock.data"
```
Make sure `e2fsprogs` package is installed!

Now add prompt indicator whenever we're running in read only or writable system and helper functions:
```bash
sudo nano /etc/bash.bashrc
```
```
# Aliases to quickly switch between read-only and read-write rootfs
alias ro='sudo mount -o remount,ro / && sudo mount -o remount,ro /boot && echo "System is now read only"'
alias rw='sudo mount -o remount,rw / && sudo mount -o remount,rw /boot && echo "System is now writable"'

# This function (un)mounts rootfs as /mnt/rootfs skipping all bind mounts
rfs() {
	if ! mount | grep /mnt/rootfs > /dev/null; then
		sudo mkdir -p /mnt/rootfs && sudo mount --bind / /mnt/rootfs && echo "Mounted rootfs without binds on /mnt/rootfs"
	else
		sudo umount /mnt/rootfs && sudo rmdir /mnt/rootfs && echo "Unmounted /mnt/rootfs"
	fi
}

# Add rootfs state indicator to command prompt
set_bash_prompt() {
	fs_mode=$(mount | sed -n -e "s/^\/dev\/.* on \/ .*(\(r[w|o]\).*/\1/p")
	PS1='\[\033[01;32m\]\u@\h${fs_mode:+($fs_mode)}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
}
PROMPT_COMMAND=set_bash_prompt
```

Credits for this go to [Andreas Schallwig](https://medium.com/swlh/make-your-raspberry-pi-file-system-read-only-raspbian-buster-c558694de79#8c4f).

## Synchronizing data partitions (optional, not recommended)

<details>
  <summary><b>Show instructions</b></summary>

If you created two data partitions it will be a good idea to keep them synchronized in case of failure.
**Keep in mind that this will decrease SD card life significantly!**

Install [this script](/scripts/datasync/) - whenever primary `/data` partition gets corrupted you will be able to replace `PARTUUID=6c586e13-03` in `/etc/fstab` with `PARTUUID=6c586e13-04` to use the backup partition, then fix or reformat the original one and synchronize the data. The script will detect which data partition is currently mounted and will always synchronize to the second.

To reduce further writes we can ignore files from synchronization:

```bash
sudo nano /etc/datasync-ignore.list
```
```
# This file contains stats and query logs
/etc/pihole/pihole-FTL.db

# Cached adlists
/etc/pihole/*.domains
```
</details>

## Backing up data partition (optional)

<details>
  <summary><b>Show instructions</b></summary>

[This script will backup /data to any location](/scripts/databackup), like network share or USB device.

Select backup destination in `/etc/databackup.conf`:

```bash
# destination path to rsync to
BACKUP_DESTINATION=/mnt/mynetworkshare/pihole-backup

# if fstab entry exist it will be auto mounted before and unmounted after
BACKUP_MOUNT=/mnt/mynetworkshare
```

You can ignore some useless files from the backup:

```bash
sudo nano /etc/databackup-ignore.list
```
```
# This file contains stats and query logs
/etc/pihole/pihole-FTL.db

# Cached adlists
/etc/pihole/*.domains
```
</details>

## Final touch

Edit boot command line and add `ro` parameter at the end:

```bash
sudo nano /boot/cmdline.txt
```
```
ro
```

Reboot the system - `sudo reboot`.
From now on the system is working in read-only mode.

## [Next: Installing Pi-hole](/02%20Pi-hole.md)
