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

#### Log on to corporate network every 6 hours
* Add below line to `crontab` or under System / Scheduled Tasks
```
0 */6 * * * wget -O - http://10.38.28.19/Auth/Status/
```

#### Install and set nano as default editor
* `opkg update`
* `opkg install nano`
* Add `export EDITOR=nano` to `/etc/profile`

#### Enabling remote SSH access
* Go to the System / Administration page.
* Under “SSH Access”, for the default “Dropbear instance”, set “Interface” to “unspecified”.
* Go to the Network / Firewall / Traffic Rules.
* Scroll down to the “Open ports on router” section.
* Enter a name for this rule, e.g. “Allow-SSH-WAN”.
* Set “Protocol” to “TCP”.
* Enter “22” as the “External Port”.
* Click “Add”.
* Click “Save and Apply”.

#### Enabling remote management
* Go to the Network / Firewall / Port Forwards.
* Scroll down to the “New port forward” section.
* Enter a name for this rule, e.g. “luci-remote”.
* Set “Protocol” to “TCP”.
* Set “External zone” to “wan”.
* Set “External port” to “9999”.
* Set “Internal zone” to “lan”.
* Leave “Internal IP address” blank.
* Enter “80” as the “Internal Port”.
* Click “Add”.
* Click “Save and Apply”.

#### Add USB Storage Device
* `opkg install kmod-usb-core kmod-usb-ohci kmod-usb-uhci kmod-usb2 kmod-usb3 usbutils kmod-usb-storage kmod-fs-ext4 block-mount kmod-scsi-core`
* Reboot
* `insmod usbcore`
* `insmod ehci-hcd`
* `insmod usb-ohci`
* `mkdir /mnt/usb1`
* `touch /mnt/usb1/USB_NOT_MOUNTED`
* `mount /dev/sda1 /mnt/usb1`
* Add mount point in System > Mount Points, with `rw,sync` options.

#### Add USB Mount Point
* Go to System / Mount Points.
* Scroll down to Mount Points.
* Click “Add” button.
* Select “Enable this mount”.
* Keep UUID and Label as it is.
* Select `/dev/sda1` from Device.
* Select `custom` from Mount Point and type `/mnt/usb1`.
* Click “Save and Apply”.

#### Add Samba Support
* `opkg install samba36-server`
* `opkg install luci-app-samba`
* Edit `/etc/config/samba` as required
* Edit `/etc/samba/smb.conf.template` as required
* Add `min protocol = SMB2` to `/etc/samba/samba.conf.template`
* Add user to `/etc/passwd` in the format `user:x:501:501:user:/home/user:/bin/ash`
* Assign a password to the user just created by running `passwd user`
* Add Samba user by running `smbpasswd -a user`
* Add below to `/etc/config/samba`
```
config 'sambashare'
        option 'name' 'usb1'
        option 'path' '/mnt/usb1'
        option 'users' 'user'
        option 'guest_ok' 'yes'
        option 'create_mask' '0700'
        option 'dir_mask' '0700'
        option 'read_only' 'no'
```
* Restart Samba server by running `/etc/init.d/samba restart`

#### Add rsync daemon
* `opkg install rsync`
* Add below to `/etc/rsyncd.conf`
```
pid file = /var/run/rsyncd.pid
log file = /var/log/rsyncd.log
lock file = /var/run/rsync.lock
use chroot = no
uid = user
gid = 501
read only = no

[usb1]
path = /mnt/usb1
comment = NAS of Ameer
list = yes
hosts allow = 192.168.7.1/24
```
* Add `rsync --daemon` to `/etc/rc.local`

#### Setting up WonderShaper
* `opkg install wshaper`
* `opkg install luci-app-wshaper`
* Set bandwidth limits in LuCI Network / Wondershaper

#### Important Links
* Configure a guest WLAN: https://wiki.openwrt.org/doc/recipes/guest-wlan-webinterface
* Guest Network for Guest WiFi: https://lede-project.org/docs/user-guide/guestwifi_configuration
* Smartphone tethering: https://lede-project.org/docs/user-guide/smartphone-usb-tether
* Enabling remote management: https://aiotutorials.wordpress.com/2016/06/28/openwrt-remote-access/
* USB Basic Support: https://wiki.openwrt.org/doc/howto/usb.essentials
* USB Storage: https://wiki.openwrt.org/doc/howto/usb.storage
* Partitioning, Formatting and Mounting Storage Devices: https://wiki.openwrt.org/doc/howto/storage
* Setting up a USB drive for storage on OpenWRT: http://www.brendangrainger.com/entries/13
* Samba (smb): https://wiki.openwrt.org/doc/uci/samba
* Share USB Hard-drive with Samba using the Luci web-interface: https://wiki.openwrt.org/doc/recipes/usb-storage-samba-webinterface
* Block a Device Based in MAC Address: https://bokunokeiken.wordpress.com/2015/06/27/how-to-block-device-on-openwrt-based-on-mac-address/
