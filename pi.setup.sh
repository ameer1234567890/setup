#!/bin/bash

#### Start of configurable variables
LOCALE='en_US.UTF-8'
TIMEZONE='Indian/Maldives'
ARM_FREQUENCY=1000
OVERCLOCK='Turbo'
USB_DRIVES="usb1 usb2 usb3 usb4 usb5 usb6 usb7 usb8 usb9 hdd1"
#### End of of configurable variables

#### .secrets.txt
# Create a file named .secrets.txt in the below format (without hashes)
# HOSTNAME='nas1.lan/nas2.lan/printer.lan/fig.lan'
# SLACK_WEBHOOK_KEY='KEY_HERE'
# ARIA2_RPC_TOKEN='TOKEN_HERE'
# THINGSPEAK_API_KEY='KEY_HERE'
# SSH_PUBLIC_KEY='KEY_HERE'
#### .secrets.txt

REBOOT_REQUIRED=false

clear
cat << "EOF"

┏┓     •
┃ ┏┓┏┓┏┓┏┓┏┏┳┓
┗┛┗┻┣┛┛┗┗┗┻┛┗┗
    ┛

* Created by: Ameer Dawood
* This script runs my customized setup process for Raspberry Pi & Orange Pi
=============================================================================

EOF

kill_tools() {
  tools="apt apt-get dpkg tar wget git"
  printf "\n\n User cancelled!\n"
  for tool in $tools; do
    if [ "$(pidof "$tool")" != "" ]; then
      printf " Killing %s... " "$tool"
    	killall "$tool" >/dev/null 2>&1
      assert_status
    fi
  done

  echo ""
  exit 0
}


trap kill_tools 1 2 3 15

if [ "$(id -u)" -ne 0 ]; then echo "Please run as root." >&2; exit 1; fi

if [ -e $(dirname -- "$0")/.secrets.txt ]; then source $(dirname -- "$0")/.secrets.txt; fi

if [ -z "$SLACK_WEBHOOK_KEY" ] || [ -z "$ARIA2_RPC_TOKEN" ] || [ -z "$THINGSPEAK_API_KEY" ] || [ -z "$SSH_PUBLIC_KEY" ] || [ -z "$HOSTNAME" ]; then
  echo "Some or all of the parameters are empty" >&2
  exit 1
fi

assert_status() {
  status=$?
  if [ $status = 0 ]; then
    printf "\e[32mDone!\e[0m\n"
  else
    printf "\e[91mFailed!\e[0m\n"
  fi
  return $status
}


print_already() { printf "\e[36mAlready Done!\e[0m\n"; }
print_opkg_busy() { printf "\e[91mopkg Busy!\e[0m\n"; }
print_not_required() { printf "\e[36mNot Required!\e[0m\n"; }
print_available() { printf "\e[36mAvailable!\e[0m\n"; }
print_unavailable() { printf "\e[91mUnavailable!\e[0m\n"; }
print_notexist() { printf "\e[36mDoes not Exist!\e[0m\n"; }


show_progress() {
  bg_pid=$1
  progress_state=0
  printf "  ⠋\b\b\b"
  while [ "$(ps | awk '{print $1}' | grep -F "$bg_pid")" != "" ]; do
    case $progress_state in
      0 ) printf "  ⠙\b\b\b" ;;
      1 ) printf "  ⠹\b\b\b" ;;
      2 ) printf "  ⠸\b\b\b" ;;
      3 ) printf "  ⠼\b\b\b" ;;
      4 ) printf "  ⠴\b\b\b" ;;
      5 ) printf "  ⠦\b\b\b" ;;
      6 ) printf "  ⠧\b\b\b" ;;
      7 ) printf "  ⠇\b\b\b" ;;
      8 ) printf "  ⠏\b\b\b" ;;
    esac
    progress_state=$(( progress_state + 1 ))
    if [ $progress_state -gt 8 ]; then
      progress_state=0
    fi
    sleep 0.01
  done
}


update_apt() {
  printf "   \e[34m•\e[0m Running apt update... "
  # diff_seconds=$(expr $(date +'%s') - $(stat -c %Y '/var/cache/apt'))
  # half_an_hour=18000 # in seconds * 1000
  # if [ $diff_seconds -lt $half_an_hour ]; then
  if [ -z "$(find -H /var/lib/apt/lists -maxdepth 0 -mmin -30)" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_hostname() {
  printf "   \e[34m•\e[0m Setting up hostname... "
  if [ $(hostnamectl --static) = $HOSTNAME ]; then
    print_already
  else
    hostnamectl set-hostname $HOSTNAME >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_locale() {
  printf "   \e[34m•\e[0m Setting up locale... "
  if [ $(localectl status | grep 'System Locale' | cut -d '=' -f 2) = $LOCALE ]; then
    print_already
  else
    localectl set-locale $LOCALE >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_timezone() {
  printf "   \e[34m•\e[0m Setting up timezone... "
  if [ $(timedatectl show | grep Timezone | cut -d '=' -f 2) = $TIMEZONE ]; then
    print_already
  else
    timedatectl set-timezone $TIMEZONE >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


notify_on_startup() {
  printf "   \e[34m•\e[0m Setting up notification on startup... "
  if [ -f /lib/systemd/system/notifyonstartup.service ]; then
    print_already
  else
    echo -e "[Unit]\nDescription=Notify on system startup\nAfter=network-online.target\n\n[Service]\nUser=pi\nExecStart=curl -X POST --data-urlencode \"payload={\\\"channel\\\": \\\"#general\\\", \\\"username\\\": \\\"NotifyBot\\\", \\\"text\\\": \\\""$(echo $HOSTNAME | cut -d . -f 1 | tr '[:lower:]' '[:upper:]')" rebooted.\\\", \\\"icon_emoji\\\": \\\":slack:\\\"}\" https://hooks.slack.com/services/"$SLACK_WEBHOOK_KEY"\nRestartSec=5\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target" > /lib/systemd/system/notifyonstartup.service && \
      systemctl enable notifyonstartup.service >/dev/null 2>&1 && \
      systemctl start notifyonstartup.service >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_overclock() {
  printf "   \e[34m•\e[0m Setting up overclock... "
  if [ $(raspi-config nonint get_config_var arm_freq /boot/config.txt) = $ARM_FREQUENCY ]; then
    print_already
  else
    raspi-config nonint do_overclock $OVERCLOCK >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
    REBOOT_REQUIRED=true
  fi
}


setup_ssh_keyfile() {
  printf "   \e[34m•\e[0m Setting up SSH key file... "
  if [ "$(grep -F "$SSH_PUBLIC_KEY" /home/pi/.ssh/authorized_keys 2>/dev/null)" != "" ]; then
    print_already
  else
    mkdir -p /home/pi/.ssh
    chown pi:pi /home/pi/.ssh
    touch /home/pi/.ssh/authorized_keys
    chown pi:pi /home/pi/.ssh/authorized_keys
    echo $SSH_PUBLIC_KEY > /home/pi/.ssh/authorized_keys 2>/dev/null
    assert_status
  fi
}


setup_apt-cacher-ng() {
  proxy_available=false
  printf "   \e[34m•\e[0m Checking proxy availability... "
  if [ "$(curl -I http://nas2.lan:3142 2> /dev/null | grep '406 Usage Information')" != "" ]; then
    proxy_available=true
    print_available
  else
    print_unavailable
  fi
  printf "   \e[34m•\e[0m Setting up apt-cacher-ng... "
  if [ $proxy_available = true ]; then
    if [ -f /etc/apt/apt.conf.d/00proxy ]; then
      print_already
    else
      echo -e "Acquire::http::Proxy \"http://nas2.lan:3142\";\nAcquire::https::Proxy \"false\";" > /etc/apt/apt.conf.d/00proxy &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  else
    print_not_required
  fi
}


mount_usb_drives() {
  for drive in $USB_DRIVES; do
    printf "   \e[34m•\e[0m Mounting USB drive: $drive... "
    if [ "$(blkid | grep $drive)" = "" ]; then
      print_notexist
    elif [ "$(mount | grep /mnt/$drive)" != "" ] || [ "$(grep /mnt/$drive /etc/fstab)" != "" ]; then
      print_already
    else
      mkdir -p /mnt/$drive && \
      touch /mnt/$drive/USB_NOT_MOUNTED && \
      echo "LABEL=$drive  /mnt/$drive  ext4  defaults,nofail,noatime  0  0" >> /etc/fstab && \
      mount -a >/dev/null 2>&1 && \
      chown pi:pi /mnt/$drive &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
}


relocate_apt_cache() {
  printf "   \e[34m•\e[0m Relocating apt cache... "
  usb_data_device=$(ls /mnt | head -n 1)
  if [ "$(grep "Dir::Cache /mnt/$usb_data_device/.data/apt-cache;" /etc/apt/apt.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    mkdir -p /mnt/$usb_data_device/.data/apt-cache && \
      echo "Dir::Cache /mnt/$usb_data_device/.data/apt-cache;" > /etc/apt/apt.conf &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


disable_password_login() {
  printf "   \e[34m•\e[0m Disabling password login... "
  if [ "$(grep "^PasswordAuthentication no" /etc/ssh/sshd_config)" != "" ]; then
    print_already
  else
    echo -e "PasswordAuthentication no\nMatch address 192.168.100.0/24\n    PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
      systemctl restart sshd.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_passwordless_sudo() {
  printf "   \e[34m•\e[0m Setting up passwordless sudo... "
  if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
    print_already
  else
    echo "pi ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/010_pi-nopasswd &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


add_zram() {
  printf "   \e[34m•\e[0m Adding zram... "
  if [ "$(grep zram /proc/swaps)" != "" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq zram-tools >/dev/null 2>&1 && \
      echo -e "vm.vfs_cache_pressure=500\nvm.swappiness=100\nvm.dirty_background_ratio=1\nvm.dirty_ratio=50" >> /etc/sysctl.conf && \
      sysctl --system >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


increase_zram() {
  printf "   \e[34m•\e[0m Increasing zram... "
  if [ "$(grep ^SIZE=2048 /etc/default/zramswap)" != "" ]; then
    print_already
  else
    echo "SIZE=2048" > /etc/default/zramswap &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_overlayroot_notice() {
  printf "   \e[34m•\e[0m Setting up overlayroot notice... "
  if [ -f /etc/profile.d/motd.sh ]; then
    print_already
  else
    echo -e "#!/bin/sh\n\nif [ -n \"\$(df | grep overlay)\" ]; then\n  echo -e \"\\\e[33m\\\n==> WARNING: Root filesystem is read only.\\\nNone of the changes you make will be preserved after reboot.\\\n\\\e[0m\"\nfi" > /etc/profile.d/motd.sh && \
      chmod +x /etc/profile.d/motd.sh &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


add_heartbeat() {
  printf "   \e[34m•\e[0m Adding heartbeat... "
  if [ "$(crontab -u pi -l | grep api.thingspeak.com)" != "" ]; then
    print_already
  else
    (crontab -u pi -l && \
      echo "* * * * * curl \"https://api.thingspeak.com/update?api_key=$THINGSPEAK_API_KEY&field1=\$(awk '/MemFree/ {print \$2}' /proc/meminfo)&field2=\$(cat /sys/class/thermal/thermal_zone0/temp | sed -r \"s/([0-9]+)([0-9]{3})/\1.\2/\")\"") | crontab -u pi - &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_google_backup() {
  printf "   \e[34m•\e[0m Setting up Google Backup... "
  if [ "$(crontab -u pi -l | grep backup-gdrive)" != "" ]; then
    print_already
  else
    usb_data_device=$(ls /mnt | head -n 1)
    DEBIAN_FRONTEND=noninteractive apt-get install -yq rclone >/dev/null 2>&1 && \
      sudo -u pi mkdir -p /home/pi/.config/rclone
      cp /mnt/$usb_data_device/Ameer/rclone.conf /home/pi/.config/rclone/rclone.conf && \
      chown pi:pi /home/pi/.config/rclone/rclone.conf && \
      (crontab -u pi -l && echo -e "0 2 * * * /mnt/$usb_data_device/Ameer/backup-gdrive-ameer.sh\n4 2 * * * /mnt/$usb_data_device/Ameer/backup-gdriveshared-ameer.sh\n7 2 * * * /mnt/$usb_data_device/Aani/backup-gdrive-aani.sh\n10 2 * * * /mnt/$usb_data_device/Ameer/backup-gphotos-ameer.sh\n30 2 * * * /mnt/$usb_data_device/Aani/backup-gphotos-aani.sh") | crontab -u pi - &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_git_backup() {
  printf "   \e[34m•\e[0m Setting up Git Backup... "
  if [ "$(crontab -u pi -l | grep gitbackup)" != "" ]; then
    print_already
  else
    usb_data_device=$(ls /mnt | head -n 1)
    DEBIAN_FRONTEND=noninteractive apt-get install -yq git >/dev/null 2>&1 && \
      (crontab -u pi -l && echo "0 3 * * * /mnt/$usb_data_device/Ameer/gitbackup/gitbackup.sh") | crontab -u pi - &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}

setup_rsync_daemon() {
  printf "   \e[34m•\e[0m Installing rsync... "
  if [ "$(dpkg-query -W -f='${Status}' rsync 2>/dev/null)" = "install ok installed" ] && [ -f /etc/rsyncd.conf ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq rsync >/dev/null 2>&1 && \
      echo -e "pid file = /var/run/rsyncd.pid\nlog file = /var/log/rsyncd.log\nlock file = /var/run/rsync.lock\nuse chroot = no\nuid = pi\ngid = pi\nread only = no\n\n" > /etc/rsyncd.conf &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  for drive in $USB_DRIVES; do
    printf "   \e[34m•\e[0m Setting up rsync daemon for $drive... "
    if [ "$(blkid | grep $drive)" = "" ]; then
      print_notexist
    elif [ "$(grep /mnt/$drive /etc/rsyncd.conf)" != "" ]; then
      print_already
    else
      echo -e "[$drive]\npath = /mnt/$drive\ncomment = $drive\nlist = yes\nhosts allow = 192.168.100.1/24,127.0.0.1,100.82.10.102" >> /etc/rsyncd.conf && \
        systemctl restart rsync.service &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
  printf "   \e[34m•\e[0m Enabling rsync service... "
  if [ "$(systemctl status rsync.service | grep disabled)" = "" ]; then
    print_already
  else
    systemctl enable rsync.service >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Starting rsync service... "
  if [ "$(systemctl status rsync.service | grep running)" != "" ]; then
    print_already
  else
    systemctl start rsync.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_samba_shares() {
  printf "   \e[34m•\e[0m Installing samba... "
  if [ "$(dpkg-query -W -f='${Status}' samba 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq samba >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  for drive in $USB_DRIVES; do
    printf "   \e[34m•\e[0m Setting up samba share for $drive... "
    if [ "$(blkid | grep $drive)" = "" ]; then
      print_notexist
    elif [ "$(grep /mnt/$drive /etc/samba/smb.conf)" != "" ]; then
      print_already
    else
      echo -e "[$drive]\n    path = /mnt/$drive\n    read only = no\n    public = yes\n    writable = yes\n    browsable = yes\n    guest ok = yes\n    create mask = 0755\n    directory mask = 0777\n    force user = pi\n    force group = pi" >> /etc/samba/smb.conf && \
        systemctl restart smbd.service &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
}


setup_aria2() {
  printf "   \e[34m•\e[0m Installing aria2... "
  usb_data_device=$(ls /mnt | head -n 1)
  if [ "$(dpkg-query -W -f='${Status}' aria2 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq aria2 >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 data folder... "
  if [ -d /mnt/$usb_data_device/.data/aria2 ]; then
    print_already
  else
    sudo -u pi mkdir -p /mnt/$usb_data_device/.data/aria2 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 session file... "
  if [ -f /mnt/$usb_data_device/.data/aria2/session ]; then
    print_already
  else
    sudo -u pi touch /mnt/$usb_data_device/.data/aria2/session &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 configuration file... "
  if [ -f /mnt/$usb_data_device/.data/aria2/aria2.conf ]; then
    print_already
  else
    echo -e "daemon=true\ndir=/mnt/$usb_data_device/aria2\nfile-allocation=prealloc\ncontinue=true\nsave-session=/mnt/$usb_data_device/.data/aria2/session\ninput-file=/mnt/$usb_data_device/.data/aria2/session\nsave-session-interval=10\nforce-save=true\nmax-connection-per-server=10\nenable-rpc=true\nrpc-listen-all=true\nrpc-secret=$ARIA2_RPC_TOKEN\nrpc-listen-port=6800\nrpc-allow-origin-all=true\non-download-complete=/mnt/$usb_data_device/.data/aria2/hook-complete.sh\non-bt-download-complete=/mnt/$usb_data_device/.data/aria2/hook-complete.sh\non-download-error=/mnt/$usb_data_device/.data/aria2/hook-error.sh\nmax-overall-download-limit=200K\nmax-concurrent-downloads=1\nquiet=true" | sudo -u pi tee /mnt/$usb_data_device/.data/aria2/aria2.conf > /dev/null &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 hook-complete file... "
  if [ -f /mnt/$usb_data_device/.data/aria2/hook-complete.sh ]; then
    print_already
  else
    echo -e "#!/bin/sh\ncurl -X POST --data-urlencode \"payload={\\\"channel\\\": \\\"#general\\\", \\\"username\\\": \\\"aria2\\\", \\\"text\\\": \\\"Download complete: \$3\\\", \\\"icon_emoji\\\": \\\":slack:\\\"}\" https://hooks.slack.com/services/$SLACK_WEBHOOK_KEY\nrm \"\$3.aria2\"" | sudo -u pi tee /mnt/$usb_data_device/.data/aria2/hook-complete.sh > /dev/null && \
      chmod +x /mnt/$usb_data_device/.data/aria2/hook-complete.sh &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 hook-error file... "
  if [ -f /mnt/$usb_data_device/.data/aria2/hook-error.sh ]; then
    print_already
  else
    echo -e "#!/bin/sh\ncurl -X POST --data-urlencode \"payload={\\\"channel\\\": \\\"#general\\\", \\\"username\\\": \\\"aria2\\\", \\\"text\\\": \\\"Download error: \$3\\\", \\\"icon_emoji\\\": \\\":slack:\\\"}\" https://hooks.slack.com/services/$SLACK_WEBHOOK_KEY" | sudo -u pi tee /mnt/$usb_data_device/.data/aria2/hook-error.sh > /dev/null && \
      chmod +x /mnt/$usb_data_device/.data/aria2/hook-error.sh &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 download directory... "
  if [ -d /mnt/$usb_data_device/aria2 ]; then
    print_already
  else
    sudo -u pi mkdir -p /mnt/$usb_data_device/aria2 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Configuring aria2 autostart... "
  if [ -f /lib/systemd/system/aria2.service ]; then
    print_already
  else
    echo -e "[Unit]\nDescription=a lightweight multi-protocol & multi-source command-line download utility\nConditionPathExists=/mnt/$usb_data_device/.data/aria2/aria2.conf\nConditionFileIsExecutable=/usr/bin/aria2c\nAfter=network-online.target mnt-$usb_data_device.mount\nDocumentation=man:aria2c(1)\n\n[Service]\nType=forking\nUser=pi\nExecStart=/usr/bin/aria2c --conf-path=/mnt/$usb_data_device/.data/aria2/aria2.conf\nRestart=always\nRestartSec=1\n\n[Install]\nWantedBy=multi-user.target" > /lib/systemd/system/aria2.service && \
      systemctl enable aria2.service >/dev/null 2>&1 && \
      systemctl start aria2.service >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_aria2_scheduling() {
  printf "   \e[34m•\e[0m Setting up aria2 scheduling... "
  if [ "$(crontab -u pi -l | grep jsonrpc)" != "" ]; then
    print_already
  else
    (crontab -u pi -l && echo "0 1 * * * curl http://127.0.0.1:6800/jsonrpc -H \"Content-Type: application/json\" -H \"Accept: application/json\" --data '{\"jsonrpc\": \"2.0\",\"id\":1, \"method\": \"aria2.changeGlobalOption\", \"params\":[\"token:$ARIA2_RPC_TOKEN\",{\"max-overall-download-limit\":\"0\"}]}'") | crontab -u pi - && \
      (crontab -u pi -l && echo "0 8 * * * curl http://127.0.0.1:6800/jsonrpc -H \"Content-Type: application/json\" -H \"Accept: application/json\" --data '{\"jsonrpc\": \"2.0\",\"id\":1, \"method\": \"aria2.changeGlobalOption\", \"params\":[\"token:$ARIA2_RPC_TOKEN\",{\"max-overall-download-limit\":\"200K\"}]}'") | crontab -u pi - &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_aria2_webui() {
  lighttpd_restart_required=false
  usb_data_device=$(ls /mnt | head -n 1)
  printf "   \e[34m•\e[0m Installing lighttpd... "
  if [ "$(dpkg-query -W -f='${Status}' lighttpd 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq lighttpd >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Enabling SSL in lighttpd... "
  if [ -f /etc/lighttpd/conf-enabled/10-ssl.conf ]; then
    print_already
  else
    lighttpd_restart_required=true
    ln -s /etc/lighttpd/conf-available/10-ssl.conf /etc/lighttpd/conf-enabled/10-ssl.conf &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Adding certificate to lighttpd... "
  if [ -f /etc/lighttpd/server.pem ]; then
    print_already
  else
    lighttpd_restart_required=true
    cat /mnt/$usb_data_device/cert/nas1.pem /mnt/$usb_data_device/cert/nas1.key > /etc/lighttpd/server.pem &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Restarting lighttpd... "
  if [ $lighttpd_restart_required = false ]; then
    print_not_required
  else
    systemctl restart lighttpd.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Installing git... "
  if [ "$(dpkg-query -W -f='${Status}' git 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq git >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Downloading aria2 webui... "
  if [ -d /mnt/$usb_data_device/.data/webui-aria2 ]; then
    print_already
  else
    git clone --quiet --depth=1 https://github.com/ziahamza/webui-aria2 /mnt/$usb_data_device/.data/webui-aria2 2>/dev/null &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Setting up aria2 webui... "
  if [ -d /var/www/html/webui-aria2 ]; then
    print_already
  else
    ln -s /mnt/$usb_data_device/.data/webui-aria2/docs /var/www/html/webui-aria2 >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


disable_swap() {
  printf "   \e[34m•\e[0m Disabling swap... "
  if [ -f /lib/systemd/system/dphys-swapfile.service ] && [ "$(systemctl status dphys-swapfile.service | grep 'disabled')" != "" ]; then
    print_already
  elif [ -f /lib/systemd/system/dphys-swapfile.service ] && [ "$(systemctl status dphys-swapfile.service | grep 'disabled')" = "" ]; then
    systemctl disable dphys-swapfile.service >/dev/null 2>&1 && \
      systemctl stop dphys-swapfile.service >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  else
    print_notexist
  fi
}


setup_remote_syslog() {
  printf "   \e[34m•\e[0m Setting up remote syslog... "
  if [ "$(grep 'syslogger.lan' /etc/rsyslog.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    echo "*.* @syslogger.lan" >> /etc/rsyslog.conf &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


install_tailscale() {
  printf "   \e[34m•\e[0m Installing Tailscale... "
  if [ "$(dpkg-query -W -f='${Status}' tailscale 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Setting up Tailscale... "
  if [ "$(cat /var/lib/tailscale/tailscaled.state 2>/dev/null)" != "{}" ]; then
    print_already
  else
    usb_data_device=$(ls /mnt | head -n 1)
    tailscale down --accept-risk=lose-ssh && \
      systemctl stop tailscaled.service && \
      cp /mnt/$usb_data_device/.data/tailscale/tailscaled.state /var/lib/tailscale/tailscaled.state && \
      systemctl start tailscaled.service && \
      tailscale up &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


install_screen() {
  printf "   \e[34m•\e[0m Installing screen... "
  if [ "$(dpkg-query -W -f='${Status}' screen 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq screen >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_overlayfs() {
  if [ $(which armbian-config) ] || [ $(which raspi-config) ] || [ "$(grep '^NAME=' /etc/os-release | cut -d '"' -f 2)" = "Debian GNU/Linux" ]; then
    printf "   \e[34m•\e[0m Installing overlayroot... "
    if [ "$(dpkg-query -W -f='${Status}' overlayroot 2>/dev/null)" = "install ok installed" ]; then
      print_already
    else
      DEBIAN_FRONTEND=noninteractive apt-get install -yq overlayroot >/dev/null 2>&1 &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
    printf "   \e[34m•\e[0m Setting up overlayfs... "
    if [ "$(grep '^overlayroot="tmpfs:swap=1,recurse=0"' /etc/overlayroot.conf)" != "" ]; then
      print_already
    else
      sed -i 's/^overlayroot=""/overlayroot="tmpfs:swap=1,recurse=0"/g' /etc/overlayroot.conf &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
      REBOOT_REQUIRED=true
    fi
  else
    printf "   \e[34m•\e[0m Setting up overlayfs... "
    print_notexist
  fi
}


install_plex() {
  printf "   \e[34m•\e[0m Adding plex repository... "
  if [ -f /usr/share/keyrings/plex-archive-keyring.gpg ]; then
    print_already
  else
    curl https://downloads.plex.tv/plex-keys/PlexSign.key 2>/dev/null | gpg --dearmor | tee /usr/share/keyrings/plex-archive-keyring.gpg >/dev/null && \
      echo "deb [signed-by=/usr/share/keyrings/plex-archive-keyring.gpg] https://downloads.plex.tv/repo/deb public main" | tee /etc/apt/sources.list.d/plexmediaserver.list >/dev/null &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
    if [ $? = 0 ]; then
      repo_added=true
    else
      repo_added=false
    fi
  fi
  printf "   \e[34m•\e[0m Running apt update... "
  if [ ! $repo_added ]; then
    print_not_required
  else
    DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Installing plexmediaserver... "
  if [ "$(dpkg-query -W -f='${Status}' plexmediaserver 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq plexmediaserver >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating symlinks to external storage... "
  if [ -L /var/lib/plexmediaserver/Library ]; then
    print_already
  else
    usb_data_device=$(ls /mnt | head -n 1)
    systemctl stop plexmediaserver.service && \
      rm -rf /var/lib/plexmediaserver/Library
      ln -s /mnt/$usb_data_device/.data/Plex/Library /var/lib/plexmediaserver/Library && \
      systemctl start plexmediaserver.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Fixing up systemd unit for plex... "
  if [ "$(grep 'ConditionPathExists' /etc/systemd/system/plexmediaserver.service.d/override.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    usb_data_device=$(ls /mnt | head -n 1)
    mkdir -p /etc/systemd/system/plexmediaserver.service.d && \
      echo -e "[Unit]\nAfter=network.target network-online.target mnt-$usb_data_device.mount\nConditionPathExists=/mnt/$usb_data_device/.data/Plex" > /etc/systemd/system/plexmediaserver.service.d/override.conf && \
      systemctl daemon-reload && \
      systemctl restart plexmediaserver.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


install_docker() {
  printf "   \e[34m•\e[0m Adding docker repository... "
  if [ -f /etc/apt/keyrings/docker.gpg ]; then
    print_already
  else
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
      echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
    if [ $? = 0 ]; then
      repo_added=true
    else
      repo_added=false
    fi
  fi
  printf "   \e[34m•\e[0m Running apt update... "
  if [ ! $repo_added ]; then
    print_not_required
  else
    DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Installing docker-ce... "
  if [ "$(dpkg-query -W -f='${Status}' docker-ce 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Assigning current user to docker group... "
  if [ "$(grep 'docker:.*:pi' /etc/group 2>/dev/null)" != "" ]; then
    print_already
  else
    usermod -aG docker pi >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
    REBOOT_REQUIRED=true
  fi
  printf "   \e[34m•\e[0m Creating symlinks to external storage... "
  if [ -L /var/lib/docker ]; then
    print_already
  else
    usb_data_device=$(ls /mnt | head -n 1)
    systemctl stop docker.service 2>/dev/null && \
      rm -rf /var/lib/docker && \
      ln -s /mnt/$usb_data_device/docker/docker /var/lib/docker && \
      systemctl start docker.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Fixing up systemd unit for docker... "
  if [ "$(grep 'ConditionPathExists' /etc/systemd/system/docker.service.d/override.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    usb_data_device=$(ls /mnt | head -n 1)
    mkdir -p /etc/systemd/system/docker.service.d && \
      echo -e "[Unit]\nAfter=network-online.target docker.socket firewalld.service containerd.service time-set.target mnt-$usb_data_device.mount\nConditionPathExists=/mnt/$usb_data_device/docker" > /etc/systemd/system/docker.service.d/override.conf && \
      systemctl daemon-reload && \
      systemctl restart docker.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_docker_caching() {
  printf "   \e[34m•\e[0m Setting up docker caching proxy... "
  if [ "$(grep 'Environment' /etc/systemd/system/docker.service.d/http-proxy.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    mkdir -p /etc/systemd/system/docker.service.d && \
      echo -e "[Service]\nEnvironment=\"HTTPS_PROXY=http://fig.lan:3128/"\" > /etc/systemd/system/docker.service.d/http-proxy.conf && \
      systemctl daemon-reload && \
      systemctl restart docker.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Installing certificates... "
  if [ "$(grep "docker_registry_proxy.crt" /etc/ca-certificates.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    curl http://fig.lan:3128/ca.crt > /usr/share/ca-certificates/docker_registry_proxy.crt 2>/dev/null && \
      echo "docker_registry_proxy.crt" >> /etc/ca-certificates.conf && \
      update-ca-certificates --fresh >/dev/null 2>&1 && \
      systemctl daemon-reload && \
      systemctl restart docker.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


install_cups() {
  printf "   \e[34m•\e[0m Installing cups... "
  if [ "$(dpkg-query -W -f='${Status}' cups 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq cups >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Setting up cups... "
  if [ "$(grep 'ServerAlias *' /etc/cups/cupsd.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    usermod -a -G lpadmin pi && \
      cupsctl --remote-admin --remote-any --share-printers && \
      echo -e "ServerAlias *\nListen 0.0.0.0:631" >> /etc/cups/cupsd.conf && \
      sed -i 's/JobPrivateValues default/JobPrivateValues none/g' /etc/cups/cupsd.conf && \
      systemctl restart cups.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


install_ppds() {
  printf "   \e[34m•\e[0m Installing hplip... "
  if [ "$(dpkg-query -W -f='${Status}' hplip 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq hplip >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Installing gutenprint... "
  if [ "$(dpkg-query -W -f='${Status}' printer-driver-gutenprint 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq printer-driver-gutenprint >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


add_printers() {
  printf "   \e[34m•\e[0m Adding Canon E460... "
  if [ "$(lpstat -v 2>/dev/null | grep Canon_E460)" != "" ]; then
    print_already
  else
    lpadmin -p Canon_E460 -D 'Canon E460' -E -v 'usb://Canon/E460%20series?serial=35F9E2&interface=1' -m 'gutenprint.5.3://bjc-E460-series/expert' -o PageSize=A4 >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Adding HP HP Deskjet 2528... "
  if [ "$(lpstat -v 2>/dev/null | grep HP_Deskjet_2528)" != "" ]; then
    print_already
  else
    lpadmin -p HP_Deskjet_2528 -D 'HP Deskjet 2528' -E -v 'usb://HP/Deskjet%202520%20series?serial=CN99P1H104069R&interface=1' -m 'hplip:0/ppd/hplip/HP/hp-deskjet_2520_series.ppd' -o PageSize=A4 >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_scan_server() {
  printf "   \e[34m•\e[0m Installing sane... "
  if [ "$(dpkg-query -W -f='${Status}' sane 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq sane >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Installing sane-utils... "
  if [ "$(dpkg-query -W -f='${Status}' sane-utils 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq sane-utils >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Installing scanservjs... "
  if [ -d /var/www/scanservjs ]; then
    print_already
  else
    curl -s https://raw.githubusercontent.com/sbs20/scanservjs/master/bootstrap.sh | bash -s -- -v latest >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


#### Tasks to run
printf "  \e[34m○\e[0m Running Common Setup:\n"
update_apt
setup_hostname
setup_locale
setup_timezone
notify_on_startup
setup_ssh_keyfile
setup_apt-cacher-ng
mount_usb_drives
relocate_apt_cache
disable_password_login
setup_passwordless_sudo
add_zram
setup_overlayroot_notice
add_heartbeat
setup_rsync_daemon
setup_samba_shares
disable_swap
setup_remote_syslog
install_tailscale
install_screen

if [ "$HOSTNAME" = "nas1.lan" ]; then
  printf "\n  \e[34m○\e[0m Running NAS1 Specific Setup:\n"
  setup_overclock
  setup_google_backup
  setup_git_backup
  setup_aria2
  setup_aria2_scheduling
  setup_aria2_webui
fi

if [ "$HOSTNAME" = "nas2.lan" ]; then
  printf "\n  \e[34m○\e[0m Running NAS2 Specific Setup:\n"
  increase_zram
  install_plex
  install_docker
  setup_docker_caching
fi

if [ "$HOSTNAME" = "printer.lan" ]; then
  printf "\n  \e[34m○\e[0m Running Print Server Specific Setup:\n"
  install_cups
  install_ppds
  add_printers
  setup_scan_server
  install_docker
  setup_docker_caching
fi

if [ "$HOSTNAME" = "fig.lan" ]; then
  printf "\n  \e[34m○\e[0m Running Fig Specific Setup:\n"
  install_docker
  setup_docker_caching
fi

printf "\n  \e[34m○\e[0m Running post-setup routines:\n"
setup_overlayfs


if [ $REBOOT_REQUIRED = true ]; then
  printf "\n\e[33mReboot required! Do you want to reboot now? (Y/N) \e[0m\n"
  read -r opt
  if [ "$opt" = "Y" ] || [ "$opt" = "y" ] || [ "$opt" = "yes" ] || [ "$opt" = "YES" ] || [ "$opt" = "Yes" ]; then
    echo "Rebooting now..."
    reboot
  fi
fi


echo "" # just an empty line before we end