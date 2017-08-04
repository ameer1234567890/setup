#### Initial Setup
* Enter `sudo raspi-config`
* Change User Password
* Change hostname
* Change Boot Options to Console Autologin
* Change Locale > Add `en_US.UTF8`
* Change Timezone to `Indian Ocean > Maldives`
* Change Keyoard Layout to `Dell > Other > English (US) > English (US)`
* Interfacing Options > enable SSH, i2c and 1-Wire
* Overclock to `Turbo`
* Advanced Options > Expand Filesystem
* `sudo reboot`
* Add network configuration at `/etc/wpa_supplicant/wpa_supplicant.conf` as below:
```
network={
    ssid="Tenda_5408C0"
    psk="password"
}
```
* Add `consoleblank=0` to the end of `/boot/cmdline.txt`
* Uncomment `LEDS=+num` in `/etc/kbd/config`
* `mkdir ~/.ssh`
* `sudo mkdir /root/.ssh`
* Add ssh keys to `~/.ssh/authorized_keys`
* Add ssh keys to `/root/.ssh/authorized_keys`
* `sudo apt install apt-cacher-ng`
* Add `Acquire::http::Proxy "http://rpi1:3142";` to `/etc/apt/apt.conf.d/00proxy`
* `sudo apt-get autoremove --purge wolfram* sonic-pi libreoffice*`
* `sudo apt-get autoremove --purge`
* `sudo apt update`
* `sudo apt upgrade`
* `sudo apt dist-upgrade`
* `sudo apt install screen aria2 python-dev`
* `wget https://bootstrap.pypa.io/get-pip.py`
* `sudo python3 get-pip.py`
* `sudo python2 get-pip.py`
* `rm get-pip.py`
* `sudo pip3 uninstall -y chardet codebug-i2c-tether codebug-tether colorama Flask gpiozero html5lib itsdangerous Jinja2 MarkupSafe mcpi numpy pgzero picamera picraft pifacecommon pifacedigitalio pigpio Pillow pygame pygobject pyinotify pyOpenSSL pyserial python-apt python-debian RTIMULib sense-emu sense-hat smbus spidev twython urllib3 Werkzeug automationhat blinkt Cap1xxx drumhat envirophat ExplorerHAT fourletterphat microdotphat mote motephat phatbeat pianohat piglow rainbowhat scrollphat scrollphathd skywriter sn3218 touchphat`
* `sudo pip2 uninstall -y blinker chardet colorama Flask gpiozero html5lib itsdangerous Jinja2 lxkeymap MarkupSafe mcpi ndg-httpsclient numpy picamera picraft pifacecommon pifacedigitalio pigpio Pillow pyasn1 pygame pygobject pyinotify pyOpenSSL pyserial python-apt RTIMULib sense-emu sense-hat smbus spidev twython urllib3 Werkzeug automationhat blinkt Cap1xxx drumhat envirophat ExplorerHAT fourletterphat microdotphat mote motephat phatbeat pianohat piglow rainbowhat scrollphat scrollphathd skywriter sn3218 touchphat`
* `git clone https://github.com/ameer1234567890/pi-scripts`
* `cd pi-scripts`
* `./install-python2-modules.sh`
* `./install-python3-modules.sh`
* `cd ..`
* Add IFTTT maker key to `~/.maker_key`
* Add Weather Underground My PWS station ID and key to `~/.wu_config.py`. Format is specified at `.wu_config.py`
* Copy `client_secret.json` into `pi-scripts` directory.
* Restore crontab from `~/pi-scripts/raspberrypi.crontab`
* Restore `/etc/rc.local` from `~/pi-scripts/raspberrypi.rc-local`
* `git config --global user.email "ameer1234567890@gmail.com"`
* `git config --global user.name "Ameer Dawood"`
* `git config --global credential.helper store`
* `git config --global push.default simple`
* Add `dtparam=act_led_gpio=25` to `/boot/config.txt`

#### Setup remot3.it
* `sudo apt-get install weavedconnectd`
* `sudo weavedinstaller`

#### Setup TV Remote
* `sudo apt-get install lirc`
* Add `dtoverlay=lirc-rpi,gpio_out_pin=17` to `/boot/config.txt`
* `sudo curl -o /etc/lirc/lircd.conf http://lirc.sourceforge.net/remotes/sony/RM-870`
* Add below to `/etc/lirc/hardware.conf`
```
LIRCD_ARGS="--uinput"
LOAD_MODULES=true
DRIVER="default"
DEVICE="/dev/lirc0"
MODULES="lirc_rpi"
LIRCD_CONF=""
LIRCMD_CONF=""
```
* Reboot
* Test LIRC using `irsend SEND_ONCE RM_870 KEY_MUTE`
* `git clone https://github.com/ameer1234567890/web-irsend`
* `sudo pip3 install Flask`
* `sudo pip2 install Flask`
