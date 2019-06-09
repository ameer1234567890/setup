#### Technical Details (Primary Router)
* Router Model: Xiaomi MiWiFi Mini
* SOC: MediaTek MT7620A
* OpenWRT Page: https://openwrt.org/toh/xiaomi/mini
* OpenWRT Hardware Data: https://openwrt.org/toh/hwdata/xiaomi/xiaomi_mini_v1

#### Technical Details (Backup Router)
* Router Model: ZBT WR8305RT
* SOC: MediaTek MT7620N
* OpenWRT Page: https://openwrt.org/toh/zbt/wr8305rt
* OpenWRT Hardware Data: https://openwrt.org/toh/hwdata/zbt/zbt_wr8305rt

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

#### Secure LuCI (HTTPS)
* `opkg install luci-ssl-openssl openssl-util luci-app-uhttpd`
* Add below to `/etc/ssl/create_root_cert_and_key.sh`
```shell
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem
```
* `chmod +x /etc/ssl/create_root_cert_and_key.sh`
* Add below to `/etc/ssl/create_certificate_for_domain.sh`
```shell
if [ -z "$1" ]
then
  echo "Please supply a subdomain to create a certificate for";
  echo "e.g. www.mysite.com"
  exit;
fi

if [ ! -f rootCA.pem ]; then
  echo 'Please run "create_root_cert_and_key.sh" first, and try again!'
  exit;
fi
if [ ! -f v3.ext ]; then
  echo 'Please create "v3.ext" file and try again!'
  exit;
fi

# Create a new private key if one doesnt exist, or use the existing one if it does
if [ -f device.key ]; then
  KEY_OPT="-key"
else
  KEY_OPT="-keyout"
fi

DOMAIN=$1
COMMON_NAME=${2:-*.$1}
SUBJECT="/C=CA/ST=None/L=NB/O=None/CN=$COMMON_NAME"
NUM_OF_DAYS=999
openssl req -new -newkey rsa:2048 -sha256 -nodes $KEY_OPT device.key -subj "$SUBJECT" -out device.csr
cat v3.ext | sed s/%%DOMAIN%%/"$COMMON_NAME"/g > /tmp/__v3.ext
openssl x509 -req -in device.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out device.crt -days $NUM_OF_DAYS -sha256 -extfile /tmp/__v3.ext 

# move output files to final filenames
mv device.csr "$DOMAIN.csr"
cp device.crt "$DOMAIN.crt"

# remove temp file
rm -f device.crt;

echo 
echo "###########################################################################"
echo Done! 
echo "###########################################################################"
echo "To use these files on your server, simply copy both $DOMAIN.csr and"
echo "device.key to your webserver, and use like so (if Apache, for example)"
echo 
echo "    SSLCertificateFile    /path_to_your_files/$DOMAIN.crt"
echo "    SSLCertificateKeyFile /path_to_your_files/device.key"
```
* `chmod +x /etc/ssl/create_certificate_for_domain.sh`
* Add below to `/etc/ssl/v3.ext`
```shell
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = %%DOMAIN%%
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = 192.168.7.1
```
* Run `cd /etc/ssl`
* Run `./create_root_cert_and_key.sh`
* Run `./create_certificate_for_domain.sh miwifimini miwifimini`

```shell
uci set uhttpd.main.listen_http='0.0.0.0:80'
uci set uhttpd.main.listen_https='0.0.0.0:443'
uci set uhttpd.main.redirect_https='1'
uci commit
```
* `/etc/init.d/uhttpd restart`
* Go to the Services / uHTTPd.
* In the field for HTTPS Certificate, paste /etc/ssl/miwifimini.crt
* In the field for HTTPS Private Key, paste /etc/ssl/device.key
* Hit save and apply.
* `/etc/init.d/uhttpd restart`
* Add `/etc/ssl/rootCA.pem` to Chrome's root certificates.

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
* First install required packages for usb storage:
```shell
opkg install kmod-usb-core usbutils kmod-usb-storage kmod-fs-ext4 block-mount
insmod usbcore
```
* For USB 3.0:
```shell
opkg install kmod-usb3
insmod xhci-hcd
```
* For USB 2.0:
```shell
opkg install kmod-usb2
insmod ehci-hcd
```
* For USB 1.1 OHCI:
```shell
opkg install kmod-usb-ohci
insmod ohci
```
* For USB 1.1 UHCI:
```shell
opkg install kmod-usb-uhci
insmod uhci
```
* Create mount directory, touch empty file, and mount:
```shell
mkdir /mnt/usb1
touch /mnt/usb1/USB_NOT_MOUNTED
mount /dev/sda1 /mnt/usb1
```

#### Add USB Mount Point
* Go to System / Mount Points.
* Scroll down to Mount Points.
* Click “Add” button.
* Select “Enable this mount”.
* Keep UUID and Label as it is.
* Select `/dev/sda1` from Device.
* Select `custom` from Mount Point and type `/mnt/usb1`.
* Go to Advanced Settings and enter `rw,sync` in Mount options.
* Click “Save and Apply”.

#### Add Samba Support
* `opkg install samba36-server`
* `opkg install luci-app-samba`
* Edit `/etc/config/samba` as required
* Edit `/etc/samba/smb.conf.template` as required
* Add `min protocol = SMB2` to `/etc/samba/smb.conf.template`
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

#### Make samba accessible from outside (WAN)
* Change `bind interfaces only` to `no` at `/etc/samba/smb.conf.template`
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

#### Setting up SQM
* `opkg install luci-app-sqm`
* Set bandwidth limits in LuCI: Network / SQM QoS

#### Adding Private Key to Dropbear
* Copy private key file to `/root` directory.
* `opkg install dropbearconvert`
* `dropbearconvert openssh dropbear /root/id_rsa /root/.ssh/id_dropbear`
* `rm /root/id_rsa`

#### Add serveo.net remote ssh
* `opkg install autossh`
* Add below to `/etc/init.d/serveo`
```shell
#!/bin/sh /etc/rc.common

START=99

start() {
  echo "Starting serveo service..."
  /usr/sbin/autossh -M 22 -y -R ameer:22:localhost:22 serveo.net < /dev/ptmx &
}

stop() {
  echo "Stopping serveo service..."
  pids="$(pgrep -f serveo.net)"
  for pid in $pids; do
    /bin/kill "$pid"
  done
}

restart() {
  stop
  start
}
```
* `chmod +x /etc/init.d/serveo`
* Run `/etc/init.d/serveo enable`
* Run `/etc/init.d/serveo start`

#### Setup aria2 and webui-aria2
* `opkg install luci-app-aria2 webui-aria2 sudo`
* `mkdir -p /home/user`
* `chown user.501 /home/user`
* `sudo -u user mkdir /home/user/.aria2`
* `sudo -u user touch /home/user/.aria2/session`
* `sudo -u user nano /home/user/.aria2/aria2.conf` and add below:
```
dir=/mnt/usb1/aria2
file-allocation=prealloc
continue=true
save-session=/root/.aria2/session
input-file=/root/.aria2/session
save-session-interval=10
force-save=true
max-connection-per-server=10
enable-rpc=true
rpc-listen-all=true
rpc-secret=_notmysecret_
rpc-listen-port=6800
rpc-allow-origin-all=true
```
* `sudo -u user mkdir /mnt/usb1/aria2`
* `/etc/init.d/aria2 disable`
* Add below to `/etc/rc.local`
```
sudo -u user aria2c --conf-path=/home/user/.aria2/aria2.conf &
```

#### Important Links
* [Configure a guest WLAN](https://openwrt.org/docs/guide-user/network/wifi/guestwifi/guest-wlan-webinterface)
* [Configure a guest WLAN](https://openwrt.org/docs/guide-user/network/wifi/guestwifi/guest-wlan)
* [Smartphone USB Tethering to an OpenWrt router](https://openwrt.org/docs/guide-user/network/wan/smartphone.usb.tethering)
* [Enabling remote management](https://aiotutorials.wordpress.com/2016/06/28/openwrt-remote-access/)
* [Installing USB Drivers](https://openwrt.org/docs/guide-user/storage/usb-installing)
* [Using storage devices](https://openwrt.org/docs/guide-user/storage/usb-drives)
* [Partitioning, Formatting and Mounting Storage Devices](https://wiki.openwrt.org/doc/howto/storage)
* [Setting up a USB drive for storage on OpenWRT](http://www.brendangrainger.com/entries/13)
* [Samba (smb)](https://openwrt.org/docs/guide-user/services/nas/samba)
* [Share USB Hard-drive with Samba using the Luci web-interface](https://openwrt.org/docs/guide-user/services/nas/usb-storage-samba-webinterface)
* [Block a Device Based in MAC Address](https://bokunokeiken.wordpress.com/2015/06/27/how-to-block-device-on-openwrt-based-on-mac-address/)
* [Secure your router's access](https://openwrt.org/docs/guide-user/security/secure.access)
* [How to get rid of LuCI https certificate warnings](https://openwrt.org/docs/guide-user/luci/getting-rid-of-luci-https-certificate-warnings)
* [Getting Chrome to accept self-signed localhost certificate](https://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate/43666288#43666288)
