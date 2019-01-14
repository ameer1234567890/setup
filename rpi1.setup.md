#### Initial Setup
* Enter `sudo raspi-config`
* Change User Password
* Change hostname
* Change Boot Options to Console Autologin
* Change Locale > Add `en_US.UTF8`
* Change Timezone to `Indian Ocean > Maldives`
* Change Keyoard Layout to `Dell > Other > English (US) > English (US)`
* Interfacing Options > enable SSH, SPI, i2c and 1-Wire
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
* `sudo apt update`
* `sudo apt upgrade`
* `sudo apt dist-upgrade`
* `sudo apt install screen git python-dev python3-dev`
* `wget https://bootstrap.pypa.io/get-pip.py`
* `sudo python3 get-pip.py`
* `sudo python2 get-pip.py`
* `rm get-pip.py`
* `git config --global user.email "ameer1234567890@gmail.com"`
* `git config --global user.name "Ameer Dawood"`
* `git config --global credential.helper store`
* `git config --global push.default simple`
* `git clone https://github.com/ameer1234567890/pi-scripts`
* `cd pi-scripts`
* `./install-python2-modules.sh`
* `./install-python3-modules.sh`
* `cd ..`
* Add IFTTT maker key to `~/.maker_key`
* Add Weather Underground My PWS station ID and key to `~/.wu_config.py`. Format is specified at `.wu_config.py`
* Copy `client_secret.json` into `pi-scripts` directory.
* Test all required scripts.
* Add all required scripts to systemd via `sudo ./install-service.sh {script.py}`
* Add below to `/etc/rc.local` before the exit.
```bash
#echo ds1307 0x68 > /sys/class/i2c-adapter/i2c-1/new_device
echo pcf8563 0x51 > /sys/class/i2c-adapter/i2c-1/new_device
sudo hwclock -s
```
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

#### Faster SSh Connections
* Add below to `/etc/ssh/sshd_config`
```
VerifyReverseMapping no
UseDNS no
```
* Restart sshd with `/etc/init.d/ssh restart`
