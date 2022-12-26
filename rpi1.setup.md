#### Initial Setup
* Enter `sudo raspi-config`
* Change User Password
* Change hostname
* Change Boot Options to Console Autologin
* Change Locale > Add `en_US.UTF8`
* Change Timezone to `Indian Ocean > Maldives`
* Change Keyoard Layout to `Dell > Other > English (US) > English (US)`
* Overclock to `Turbo`
* Advanced Options > Expand Filesystem
* `sudo reboot`
* `mkdir ~/.ssh`
* Add ssh keys to `~/.ssh/authorized_keys`


#### Install & Setup apt-cacher-ng
* `sudo apt install apt-cacher-ng`
* Add `Acquire::http::Proxy "http://nas2.lan:3142";` to `/etc/apt/apt.conf.d/00proxy`
* Add `PassThroughPattern: ^(.*):443$` to `/etc/apt-cacher-ng/acng.conf`

#### Configure apt cache location
* Add below to `/etc/apt/apt.conf`
```
Dir::Cache /mnt/usb2/.data/apt-cache;
```

#### Configure apt-cacher-ng cache location
* Change below in `/etc/apt-cacher-ng/acng.conf`
```
CacheDir: /mnt/usb2/.data/apt-cacher-ng/cache
LogDir: /mnt/usb2/.data/apt-cacher-ng/log
```

#### Install pip
* `wget https://bootstrap.pypa.io/get-pip.py`
* `sudo python3 get-pip.py`
* `rm get-pip.py`

#### Setup git
* `sudo apt install git`
* `git config --global user.email "ameer1234567890@gmail.com"`
* `git config --global user.name "Ameer Dawood"`

#### Disable Password Logins via SSH
* Add below to `/etc/ssh/sshd_config`
```
PasswordAuthentication no
Match address 192.168.100.0/24
    PasswordAuthentication yes
```
* Run `sudo service ssh reload`

#### Cache pip wheels
```
pip wheel --wheel-dir=/mnt/usb2/.data/pip cssselect==0.9.1
pip install /mnt/usb2/.data/pip/cssselect-0.9.1-py2-none-any.whl
```

#### Add reboot notification
* Add below to `/etc/rc.local`, replacing API key as required
```
sleep 14 && curl -X POST --data-urlencode "payload={\"channel\": \"#general\", \"username\": \"NotifyBot\", \"text\": \"NAS1 rebooted.\", \"icon_emoji\": \":slack:\"}" https://hooks.slack.com/services/XXXXXXX/XXXXXX/XXXXXXXXXXXXXXXXXXX
```

#### Add heartbeat
* Add below to `crontab -e`, replacing API key as required
```
* * * * * curl "https://api.thingspeak.com/update?api_key=XXXXXXXXXXXXXXXX&field1=$(awk '/MemFree/ {print $2}' /proc/meminfo)&field2=$(vcgencmd measure_temp | cut -d = -f 2 | cut -d \' -f 1)"
```

#### Google Drive backup using rclone
* `sudo apt install rclone`
* `cp /mnt/usb1/Ameer/rclone.conf /home/pi/.config/rclone/rclone.conf`
* Add below to `crontab -e`
```
0 2 * * * /mnt/usb1/Ameer/backup-gdrive-ameer.sh
4 2 * * * /mnt/usb1/Ameer/backup-gdriveshared-ameer.sh
7 2 * * * /mnt/usb1/Aani/backup-gdrive-aani.sh
```

#### git backup
* `sudo apt install git`
* Add below to `crontab -e`
```
0 3 * * * /mnt/usb1/Ameer/gitbackup/gitbackup.sh
```

#### Disable WiFi if wired
* Add below to `/etc/rc.local`, replacing interface names as required
```
# Disable WiFi if wired.
logger "Checking Network interfaces..."
if ethtool eth0 | egrep "Link.*yes" && ifconfig eth0 | grep "inet"; then
  logger 'Disabling WiFi...'
  ifconfig wlan0 down
else
  logger 'WiFi is still enabled: Ethernet is down or ethtool is not installed.'
fi
```

#### Setup rsync
* `sudo apt install rsync`
* Add below to `/etc/rsyncd.conf`
```
pid file = /var/run/rsyncd.pid
log file = /var/log/rsyncd.log
lock file = /var/run/rsync.lock
use chroot = no
uid = pi
gid = pi
read only = no

[usb1]
path = /mnt/usb1
comment = usb1
list = yes
hosts allow = 192.168.100.1/24
```
* `sudo systemctl restart rsync.service`

#### Password-less Samba Shares
* Add below to `/etc/samba/smb.conf`
```
[usb2]
    path = /mnt/usb2
    read only = no
    public = yes
    writable = yes
    browsable = yes
    guest ok = yes
    create mask = 0755
    directory mask = 0777
    force user = pi
    force group = pi
```
* `sudo systemctl restart smbd.service`

#### Install & Setup aria2
* `sudo apt install aria2 lighttpd`
* `sudo ln -s /mnt/usb1/.data/webui-aria2/docs /var/www/html/webui-aria2`
* Add below to `/lib/systemd/system/aria2.service`
```
[Unit]
Description=a lightweight multi-protocol & multi-source command-line download utility
ConditionPathExists=/mnt/usb1/.data/aria2/aria2.conf
ConditionFileIsExecutable=/usr/bin/aria2c
After=network.target mnt-usb1.mount
Documentation=man:aria2c(1)

[Service]
Type=forking
User=pi
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/aria2c --conf-path=/mnt/usb1/.data/aria2/aria2.conf
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
```
* `sudo systemctl enable aria2.service`
* `sudo systemctl start aria2.service`

#### Enable swap support in read-only mode
* `sudo dphys-swapfile swapoff`
* Change `CONF_SWAPSIZE=100` in `/etc/dphys-swapfile` to `CONF_SWAPSIZE=50`
* Uncomment and change `CONF_SWAPFILE` in `/etc/dphys-swapfile` to `/boot/swap`
* `sudo dphys-swapfile setup`
* `sudo dphys-swapfile swapon`

#### Install & Setup CUPS Printer
* `sudo apt install cups`
* `sudo usermod -a -G lpadmin pi`
* `sudo cupsctl --remote-admin --remote-any --share-printers`
* Add below to `/etc/cups/cupsd.conf`
```
ServerAlias *
Listen 0.0.0.0:631
```
* `sudo /etc/init.d/cups restart`
* Access CUPS webui at `http://127.0.0.1:631`

#### Install HPLIP (Support for HP Printers)
* `sudo apt install hplip`

#### Install GutenPrint (Support for Canon Printers)
* `sudo apt install printer-driver-gutenprint`

#### Install brlaser (Support for Brother Printers)
* `sudo apt install printer-driver-brlaser`

#### Install escpr (Support for Epson Printers)
* `sudo apt install printer-driver-escpr`

#### Install splix (Support for Samsung Printers)
* `sudo apt install printer-driver-splix`

#### Install foo2zjs (Support for ZjStream-based Printers)
* `sudo apt install printer-driver-foo2zjs`

#### How to turn off Unknown Name and Withheld User in the CUPS web interface
* Change below in `/etc/cups/cupsd.conf`
* Change `JobPrivateValues default` to `JobPrivateValues none`
* `sudo /etc/init.d/cups restart`

#### Persist CUPS job status
* Set mount options for `/boot` to add `fmask=000,dmask=000` in `/etc/fstab`
* `sudo cp -r /var/spool/cups /boot/cups`
* `sudo rm -rf /var/spool/cups`
* `sudo ln -s /boot/cups /var/spool`
* Reboot

#### Setup Samba Print Service
* Add below to `/etc/samba/smb.conf` under `[global]`
```
rpc_server:spoolss = external
rpc_daemon:spoolssd = fork
printing = CUPS
```
* `sudo mkdir -p /var/spool/samba/`
* `sudo chmod 1777 /var/spool/samba/`
* `sudo smbcontrol all reload-config`
* `sudo systemctl restart smbd.service`

#### Add cups printer in Windows
* Go to printers and scanners
* Click Add printer or scanner
* Wait for a while (about 15 seconds)
* Click `The printer that I want is not listed`
* In the dialog box, select `Select a shared printer by name`
* Enter `http://printer.lan:631/printers/HP_Deskjet_2528` in the textbox (replace printer name with the name setup in CUPS)
* Click Next

#### Install SANE scanner backend
* `sudo apt install sane sane-utils`
* Run `scanimage -L` and see if the scanner is shown in the output

#### Install scanservjs frontend for SANE
* `sudo apt install nodejs npm imagemagick sane-utils update-inetd tesseract-ocr tesseract-ocr-ces tesseract-ocr-chi-sim tesseract-ocr-deu tesseract-ocr-fra tesseract-ocr-ita tesseract-ocr-nld tesseract-ocr-pol tesseract-ocr-por tesseract-ocr-rus tesseract-ocr-spa tesseract-ocr-tur`
* Go to `https://github.com/sbs20/scanservjs` and follow installation instructions

#### Setup remote rsyslog server logging
* Add below to `/etc/rsyslog.conf`
```
*.* @syslogger.lan
```
* `sudo systemctl restart rsyslog.service`
