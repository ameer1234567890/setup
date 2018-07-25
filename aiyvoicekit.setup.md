### Google AIY Voice Kit
* Setup Instructions: https://aiyprojects.withgoogle.com/voice
* Github Repo: https://github.com/google/aiyprojects-raspbian
* Software Setup Instructions: https://github.com/google/aiyprojects-raspbian/blob/aiyprojects/HACKING.md

#### Setting up software on Raspberry Pi
* Copy credentials file to `/home/pi/assistant.json`
```bash
sudo apt install alsa-utils python3-all-dev rsync ntpdate libttspico-utils git
wget https://bootstrap.pypa.io/get-pip.py
sudo python3 get-pip.py
sudo pip3 install virtualenv
git clone https://github.com/google/aiyprojects-raspbian.git ~/AIY-projects-python
cd ~/AIY-projects-python
virtualenv env
source env/bin/activate
pip3 install google_auth_oauthlib numpy pysocks RPi.GPIO
pip3 install -r requirements.txt
scripts/install-deps.sh
sudo scripts/install-services.sh
cp src/examples/voice/assistant_library_with_local_commands_demo.py src/main.py
sudo scripts/configure-driver.sh
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
* If no voice from the assistant, fix it by saying `OK Google, set volume to 80%`
* If alsa volume resets occationally, run the below:
```bash
sudo alsactl store
sudo systemctl add-wants sound.target alsa-restore.service
sudo systemctl daemon-reload
sudo systemctl enable alsa-restore.service
```
