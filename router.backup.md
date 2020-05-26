#### Backup Files (These need to be entered in OpenWrt's backup interface)
```
/home/user
/root
/etc/rsyncd.conf
/etc/init.d/serveo
/etc/init.d/gadhamoo
/bin/bash
```

#### Commands to run (These commands need to be run after upgrading)
```
opkg install openssh-sftp-server nano rsync autossh screen bash htop aria2 sudo curl samba36-server luci-app-samba kmod-usb-core usbutils kmod-usb-storage kmod-fs-ext4 block-mount
mkdir /mnt/usb1
touch /mnt/usb1/USB_NOT_MOUNTED
ln -s /mnt/usb1/.data/webui-aria2/docs /www/webui-aria2
/etc/init.d/serveo enable
/etc/init.d/gadhamoo enable
/etc/init.d/aria2 disable
/etc/init.d/cron enable
```
