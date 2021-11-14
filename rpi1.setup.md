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
* Add below to `/etc/rc.local`
```
/usr/bin/aria2c --conf-path=/mnt/usb1/.data/aria2/aria2.conf &
```

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
* Enter `http://127.0.0.1:631/printers/HP_Deskjet_2520_series` in the textbox (replace printer name with the name setup in CUPS)
* Click Next

#### Install SANE scanner backend
* `sudo apt install sane sane-utils`
* Run `scanimage -L` and see if the scanner is shown in the output

#### Install scanservjs frontend for SANE
* `sudo apt install nodejs npm imagemagick tesseract-ocr`
* Go to `https://github.com/sbs20/scanservjs` and follow installation instructions

#### Setup remote rsyslog server logging
* Add below to `/etc/rsyslog.conf`
```
*.* @syslogger.lan
```
* `sudo systemctl restart rsyslog.service`
