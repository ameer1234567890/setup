#### Technical Details
* Router Model: ZBT WR8305RT
* SOC: MediaTek MT7620N
* OpenWRT Page: https://wiki.openwrt.org/toh/zbt/wr8305rt

#### Notify on router startup (via IFTTT)
Add below line to `/etc/rc.local` or under Local Startup at System / Startup in LuCI
```shell
sleep 14
wget -O - http://maker.ifttt.com/trigger/router-reboot/with/key/{IFTTT_KEY_HERE}
```

#### Install the openssh-sftp-server package to install support for the SFTP protocol which SSHFS uses
```shell
opkg update
opkg install openssh-sftp-server
```

#### Enabling remote SSH access
1. Go to the System / Administration page.
2. Under “SSH Access”, for the default “Dropbear instance”, set “Interface” to “unspecified”.
3. Go to the Network / Firewall / Traffic Rules.
4. Scroll down to the “Open ports on router” section.
5. Enter a name for this rule, e.g. “Allow-SSH-WAN”.
6. Set “Protocol” to “TCP”.
7. Enter “22” as the “External Port”.
8. Click “Add”.
9. Click “Save and Apply”.

#### Enabling remote management
1. Go to the Network / Firewall / Port Forwards.
2. Scroll down to the “New port forward” section.
3. Enter a name for this rule, e.g. “luci-remote”.
4. Set “Protocol” to “TCP”.
5. Set “External zone” to “wan”
6. Set “External port” to “9999”
7. Leave “Internal IP address” blank.
8. Enter “80” as the “Internal Port”.
9. Click “Add”.
10. Click “Save and Apply”.

#### Add USB Storage Device
1. `opkg install kmod-usb-core kmod-usb-ohci kmod-usb-uhci kmod-usb2 kmod-usb3 usbutils`
2. `insmod usbcore`
3. `insmod ehci-hcd`
4. `insmod usb-ohci`
5. `opkg install kmod-usb-storage`
6. `opkg install kmod-fs-ext4`
7. `opkg install block-mount`
8. `opkg install kmod-scsi-core`
9. `mkdir /mnt/usb1`
10. `mount /dev/sda1 /mnt/usb1`
11. `touch /mnt/usb1/USB_NOT_MOUNTED`
12. Add mount point in System > Mount Points, with `rw,sync,umask=000` options.

#### Add Samba Support
1. `opkg install samba36-server`
2. `opkg install luci-app-samba`
3. Edit `/etc/config/samba` as required
4. Add user to `/etc/passwd` in the format `user:x:501:501:user:/home/user:/bin/ash`
5. Assign a password to the user just created by running `passwd user`
6. Add Samba user by running `smbpasswd -a user`
7. Add below to `/etc/config/samba`
```shell
config 'sambashare'
        option 'name' 'usb1'
        option 'path' '/mnt/usb1'
        option 'users' 'user'
        option 'guest_ok' 'yes'
        option 'create_mask' '0700'
        option 'dir_mask' '0700'
        option 'read_only' 'no'
```
8. Restart Samba server by running `/etc/init.d/samba restart`

#### Add rsync daemon
* `opkg install rsync`
* Add below to `/etc/rsyncd.conf`
```shell
pid file = /var/run/rsyncd.pid
log file = /var/log/rsyncd.log
lock file = /var/run/rsync.lock
use chroot = yes
uid = user
gid = 501
read only = no

[usb1]
path = /mnt/usb1
comment = Nexus 5X Storage Sync
list = yes
hosts allow = {IP_ADDRESSES_SEPARATED_BY_COMMA}
```
* Add `rsync --daemon` to `/etc/rc.local`

#### Important Links
* Configure a guest WLAN: https://wiki.openwrt.org/doc/recipes/guest-wlan-webinterface
* Enabling remote management: https://aiotutorials.wordpress.com/2016/06/28/openwrt-remote-access/
* USB Basic Support: https://wiki.openwrt.org/doc/howto/usb.essentials
* USB Storage: https://wiki.openwrt.org/doc/howto/usb.storage
* Partitioning, Formatting and Mounting Storage Devices: https://wiki.openwrt.org/doc/howto/storage
* Setting up a USB drive for storage on OpenWRT: http://www.brendangrainger.com/entries/13
* Samba (smb): https://wiki.openwrt.org/doc/uci/samba
* Share USB Hard-drive with Samba using the Luci web-interface: https://wiki.openwrt.org/doc/recipes/usb-storage-samba-webinterface
