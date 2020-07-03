# Raspberry Pi - read-only system

**This method is only for headless projects, it is assumed desktop features will not be used.**

We create additional writable data partition(s) that will contain required directories and files for the system to work correctly.

Tested on Raspbian Buster Lite (September 2019) + Raspberry Pi Zero W

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

Raspbian probably auto-expanded filesystem on first boot to fill the SD card - we don't want that - shutdown the Pi (`sudo shutdown -r now`), take the SD card out and insert it into computer's card reader for repartitioning.
Shrink rootfs partition to reasonable size (around 4-6GB should be fine for simple projects) and create a data partition (preferably at the end of the SD card).

This is how it looks like in case of my 16GB card:

| device         | fs    | label  | size   |
|----------------|-------|--------|--------|
| /dev/sda1      | fat32 | boot   | 256MB  |
| /dev/sda2      | ext4  | rootfs | 6GB    |
| - free space - |       |        | ~0.5GB |
| /dev/sda3      | ext4  | data1  | 8GB    |

Now you can put the card back into the Pi and boot it.

If you're really worried about data partition getting corrupted you could create two of them and keep them in sync them with [this script](/scripts/datasync/) (make sure they are `/dev/sda3` and `/dev/sda4` respectively).

_Alternatively you can repartition instantly after flashing but first boot might fail (stuck on IO LED just being on) and you will have to manually reboot the Pi._

## Preparations

Tweak boot configuration:
```bash
sudo nano /boot/config.txt
```
```
# Comment out this line, we do not need audio
#dtparam=audio=on

# Reduce memory reserved for GPU
gpu_mem=16

# Pi Zero only: Invert ACT LED state
# Saves 'some' power by keeping the LED in off state when powered on, still blinks on IO
dtparam=act_led_activelow=on

# Enable hardware watchdog, automatic reboots when device hangs
dtparam=watchdog=on

# Disable Bluetooth, unless you're going to use it
dtoverlay=disable-bt

# Disable WiFi, unless you're going to use it
dtoverlay=disable-wifi
```

Disable HDMI on boot: 
```bash
sudo nano /etc/rc.local
```
```
# Disable HDMI port
/opt/vc/bin/tvservice -o

exit 0
```

Install `watchdog`:
```bash
sudo apt install watchdog
```

Modify it's config:
```bash
sudo nano /etc/watchdog.conf
```
```
watchdog-device = /dev/watchdog
max-load-1 = 24
watchdog-timeout = 15
```

Start it and enable on boot:
```bash
sudo systemctl start watchdog && sudo systemctl enable watchdog
```

Disable SWAP:
```bash
sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall
sudo systemctl disable dphys-swapfile.service
```
_You can re-enable it later by reconfiguring it to use the data partition, if you really need it._

Other stuff to uninstall and disable:

```bash
sudo apt remove --purge --autoremove fake-hwclock triggerhappy

# Not needed on headless system
sudo systemctl disable console-setup.service

# No point for these to run since APT can't run on read-only filesystem
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily.service
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable apt-daily-upgrade.service
```

## Setting up the read-only mode

Edit `/etc/fstab` (`PARTUUID` might be different - adjust accordingly):
```
proc                  /proc  proc  defaults                                   0 0
PARTUUID=6c586e13-01  /boot  vfat  defaults,ro                                0 2
PARTUUID=6c586e13-02  /      ext4  defaults,noatime,ro                        0 1
PARTUUID=6c586e13-03  /data  ext4  defaults,noatime,nofail,errors=remount-ro  0 2

# RAMdisk
tmpfs  /tmp      tmpfs  defaults,noatime,mode=1777,size=100M  0 0
/tmp   /var/tmp  none   bind,nofail                           0 0
tmpfs  /var/log  tmpfs  defaults,noatime,mode=0755            0 0
tmpfs  /mnt      tmpfs  defaults,noatime,size=1M              0 0
```

_You can increase /tmp size as you wish - I recommend setting it to max 50% of total RAM_

Remount everything with `sudo mount -a`. 

To continue, we need the system to be writable so:
```bash
sudo mount -o remount,rw /
sudo mount -o remount,rw /boot
```

We need to move some directories to the writable partition:
```bash
# Home directories (optional, recommended)
sudo cp -a /home /data

sudo mkdir -p /data/var/lib/

# Required for systemd features to function properly
sudo cp -a /var/lib/systemd /data/var/lib

# Logrotate needs this to function (optional, recommended)
sudo cp -a /var/lib/logrotate /data/var/lib
```

And add binds to `/etc/fstab`:
```
# Required binds for read-only filesystem
# System
/data/home               /home               none  bind,nofail  0 0
/data/var/lib/systemd    /var/lib/systemd    none  bind,nofail  0 0
/data/var/lib/logrotate  /var/lib/logrotate  none  bind,nofail  0 0
```

Apply changes - `sudo mount -a`.

You might need to run these again:
```bash
sudo mount -o remount,rw /
sudo mount -o remount,rw /boot
```

Add an override in **logrotate** configuration for all log files:

```bash
sudo nano /etc/logrotate.conf
```
```
# put a comment here
#include /etc/logrotate.d

# system-specific logs may be also be configured here.

# For read-only filesystem
/var/log/*
/var/log/**/*
{
  daily
  rotate 1
  minsize 1M
  copytruncate
  compress
  notifempty
}
```

Add prompt indicator whenever we're running in read only or writable system and helper functions:
```bash
sudo nano /etc/bash.bashrc
```
```
alias ro='sudo mount -o remount,ro / && sudo mount -o remount,ro /boot && echo "System is now read only"'
alias rw='sudo mount -o remount,rw / && sudo mount -o remount,rw /boot && echo "System is now writable"'

# Credits to https://medium.com/swlh/make-your-raspberry-pi-file-system-read-only-raspbian-buster-c558694de79#8c4f
set_bash_prompt() {
	fs_mode=$(mount | sed -n -e "s/^\/dev\/.* on \/ .*(\(r[w|o]\).*/\1/p")
	PS1='\[\033[01;32m\]\u@\h${fs_mode:+($fs_mode)}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
}
PROMPT_COMMAND=set_bash_prompt
```

Credits for this go to [Andreas Schallwig](https://medium.com/swlh/make-your-raspberry-pi-file-system-read-only-raspbian-buster-c558694de79#8c4f).

## Synchronizing data partitions (optional)

If you created two data partitions it will be a good idea to keep them synchronized in case of failure.

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

## Backing up data partition (optional)

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


## Final touch

Edit boot command line and add `ro` parameter:

```bash
sudo nano /boot/cmdline.txt
```
```
ro
```

Reboot the system - `sudo reboot`.
From now on the system is working in read-only mode.

## [Next: Installing Pi-hole](/02%20Pi-hole.md)
