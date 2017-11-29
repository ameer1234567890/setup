### Google AIY Voice Kit
* Setup Instructions: https://aiyprojects.withgoogle.com/voice
* Github Repo: https://github.com/google/aiyprojects-raspbian
* Software Setup Instructions: https://www.raspberrypi.org/forums/viewtopic.php?t=188958

#### Setting up software on Raspberry Pi
```bash
git clone https://github.com/google/aiyprojects-raspbian.git ~/voice-recognizer-raspi
cd ~/voice-recognizer-raspi
scripts/install-deps.sh
sudo scripts/install-services.sh
cp src/assistant_library_with_local_commands_demo.py src/main.py
sudo systemctl enable voice-recognizer.service
```

#### How to Update
To update the Assistant API on Raspbian to a newer version, run these commands:
```bash
cd ~/voice-recognizer-raspi
git checkout voicekit
git pull origin voicekit
rm -rf ~/voice-recognizer-raspi/env
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
