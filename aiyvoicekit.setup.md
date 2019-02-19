### Google AIY Voice Kit
* Setup Instructions: https://aiyprojects.withgoogle.com/voice
* Github Repo: https://github.com/google/aiyprojects-raspbian
* Software Setup Instructions: https://github.com/google/aiyprojects-raspbian/blob/aiyprojects/HACKING.md

#### Setting up software on Raspberry Pi
* Copy credentials file to `/home/pi/assistant.json`
```bash
echo "deb https://dl.google.com/aiyprojects/deb stable main" | sudo tee -a /etc/apt/sources.list.d/aiyprojects.list
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo apt update
sudo apt upgrade
sudo reboot
sudo apt install pulseaudio
mkdir -p ~/.config/pulse/
echo "default-sample-rate = 48000" > ~/.config/pulse/daemon.conf
sudo mkdir -p /usr/lib/systemd/system/
sudo apt install libatlas-base-dev # Required for numpy
sudo apt install libjpeg-dev # Required for Pillow
sudo apt install aiy-dkms aiy-voicebonnet-soundcard-dkms aiy-voicebonnet-routes
sudo reboot
sudo apt install git
git clone https://github.com/google/aiyprojects-raspbian.git AIY-projects-python
virtualenv ~/AIY-projects-python/env
source ~/AIY-projects-python/env/bin/activate
pip install google_auth_oauthlib
pip install numpy
pip install -e ~/AIY-projects-python/src
cp ~/AIY-projects-python/src/examples/voice/assistant_library_with_local_commands_demo.py ~/AIY-projects-python/src/main.py
sudo reboot
sudo systemctl enable voice-recognizer.service
```

#### Testing
```bash
cd ~/AIY-projects-python
source env/bin/activate
python3 src/main.py
```

#### How to Update
To update the Assistant API on Raspbian to a newer version, run these commands:
```bash
cd ~/AIY-projects-python
git checkout aiyprojects
git pull origin aiyprojects
rm -rf env
scripts/install-deps.sh
```

#### My modifications
* Download ding sound with `curl https://raw.githubusercontent.com/ameer1234567890/setup/master/ding.wav -o ding.wav`
* Download boot sound with `curl https://raw.githubusercontent.com/ameer1234567890/setup/master/boot_mono.wav -o boot_mono.wav`
* Add below patch in `src/main.py`
```python
def process_event(assistant, event):
    status_ui = aiy.voicehat.get_status_ui()
    if event.type == EventType.ON_START_FINISHED:
        status_ui.status('ready')
+       subprocess.call('amixer sset \'Master\' 140,140', shell=True)
+       aiy.audio.play_wave('/home/pi/boot_mono.wav')
+       subprocess.call('amixer sset \'Master\' 204,204', shell=True)
        if sys.stdout.isatty():
            print('Say "OK, Google" then speak, or press Ctrl+C to quit...')

    elif event.type == EventType.ON_CONVERSATION_TURN_STARTED:
        status_ui.status('listening')
+       aiy.audio.play_wave('/home/pi/ding.wav')
```
* Then adjust volume with `alsamixer`
* Comment out below line:
```python
        elif text == 'reboot':
            #assistant.stop_conversation()
            reboot_pi()
```
* Comment out below line and add `time.sleep`
```python
def reboot_pi():
    #aiy.audio.say('See you in a bit!')
    time.sleep(4)
    subprocess.call('sudo reboot', shell=True)
```
* Add `time` module after `sys` module:
```python
import time
```

#### Troubleshooting
* If there is no sound from `aplay`, copy below to `/boot/config.txt`
```bash
dtoverlay=googlevoicehat-soundcard
```

* If no voice from the assistant, fix it by saying `OK Google, set volume to 80%`
* If alsa volume resets occationally, run the below:
```bash
sudo alsactl store
sudo systemctl add-wants sound.target alsa-restore.service
sudo systemctl daemon-reload
sudo systemctl enable alsa-restore.service
```

* If alsamixer volume levels are being ignored, backup and remove below files:
```bash
/root/.config/pulse
/etc/pulse
/home/pi/.config/pulse
/run/alsa/.config/pulse
/run/user/1000/pulse
```
