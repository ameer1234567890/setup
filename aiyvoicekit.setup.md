### Google AIY Voice Kit
* Setup Instructions: https://aiyprojects.withgoogle.com/voice
* Github Repo: https://github.com/google/aiyprojects-raspbian
* Software Setup Instructions: https://github.com/google/aiyprojects-raspbian/blob/aiyprojects/HACKING.md

#### Setting up software on Raspberry Pi
```bash
sudo apt install alsa-utils python3-all-dev rsync ntpdate libttspico-utils
wget https://bootstrap.pypa.io/get-pip.py
sudo python3 get-pip.py
sudo pip3 install virtualenv RPi.GPIO
git clone https://github.com/google/aiyprojects-raspbian.git ~/AIY-projects-python
cd ~/AIY-projects-python
virtualenv env
source env/bin/activate
pip3 install google_auth_oauthlib numpy pysocks
pip3 install -r requirements.txt
scripts/install-deps.sh
sudo scripts/install-services.sh
cp src/examples/voice/assistant_library_with_local_commands_demo.py src/main.py
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
* Download ding sound with `curl -Lb gcokie "https://drive.google.com/uc?export=download&confirm=Uq6r&id=0B6mVphrY3XTFSGlUeWhmc0dnUlE" -o "ding.wav"`
* Add below patch in `src/main.py`
```python
def process_event(assistant, event):
    status_ui = aiy.voicehat.get_status_ui()
    if event.type == EventType.ON_START_FINISHED:
        status_ui.status('ready')
+       aiy.audio.say('Hi')
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
