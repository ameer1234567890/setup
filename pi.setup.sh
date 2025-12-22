#!/bin/bash

#### Start of configurable variables
LOCALE='en_US.UTF-8'
TIMEZONE='Indian/Maldives'
ARM_FREQUENCY=1000
OVERCLOCK='Turbo'
USB_DRIVES="usb1 usb2 usb3 usb4 usb5 usb6 usb8 hdd1 mmc1"
declare -A backup_script
backup_script=( \
  ["usb1"]="backup.sh" \
  ["usb2"]="backup-terabox.sh" \
  ["usb3"]="backup.sh" \
  ["usb4"]="backup-terabox.sh" \
  ["usb5"]="backup-gdrive.sh" \
  ["usb6"]="backup-terabox.sh" \
  ["usb8"]="backup.sh" \
  ["hdd1"]="backup.sh" \
  ["mmc1"]="backup.sh" \
)
backup_schedule=( \
  ["usb1"]="30 2 * * *" \
  ["usb2"]="40 0 * * *" \
  ["usb3"]="50 0 * * *" \
  ["usb4"]="10 1 * * *" \
  ["usb5"]="20 1 * * *" \
  ["usb6"]="30 1 * * *" \
  ["usb8"]="30 0 * * *" \
  ["hdd1"]="10 0 * * *" \
  ["mmc1"]="20 0 * * *" \
)
#### End of of configurable variables

#### .secrets.txt
# Create a file named .secrets.txt in the below format (without hashes)
# HOSTNAME='nas1.lan/nas2.lan/printer.lan/fig.lan/apricot.lan'
# ARIA2_RPC_TOKEN='TOKEN_HERE'
# SSH_PUBLIC_KEY='KEY_HERE'
# USB_DATA_DEVICE='usb1|usb3|usb8|hdd1|mmc1'
# TELEGRAM_BOT_TOKEN='TOKEN_HERE'
# TELEGRAM_CHATID='CHATID_HERE'
# SAMBA_PASSWORD='PASSWORD_HERE'
#### .secrets.txt

REBOOT_REQUIRED=false

clear
cat << "EOF"

┏┓     •
┃ ┏┓┏┓┏┓┏┓┏┏┳┓
┗┛┗┻┣┛┛┗┗┗┻┛┗┗
    ┛

* Created by: Ameer Dawood
* This script runs my customized setup process for my HomeLab's linux devices
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

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHATID" ] || [ -z "$ARIA2_RPC_TOKEN" ] || [ -z "$SSH_PUBLIC_KEY" ] || [ -z "$HOSTNAME" ] || [ -z "$SAMBA_PASSWORD" ]; then
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


read -r -d "" usb_checker_script << EOF
#!/bin/bash

TELEGRAM_CHATID="$TELEGRAM_CHATID"
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
EOF

usb_checker_script+=$(cat << "EOF"

USB_DRIVES="$(grep usb /etc/fstab | cut -d= -f2 | cut -d' ' -f1)"

for drive in $USB_DRIVES; do
  if [ "$(ls /mnt/$drive/check_mount.sh)" ] && [ "$(ls -l /mnt/$drive/check_mount.sh 2>&1 | grep 'Input/output error')" = "" ] && [ "$(ls -l /mnt/$drive 2>&1 | grep 'Input/output error')" = "" ]; then
    echo "$drive OK"
  else
    sudo mount -a
    if [ "$(ls /mnt/$drive/check_mount.sh)" ] && [ "$(ls -l /mnt/$drive/check_mount.sh 2>&1 | grep 'Input/output error')" = "" ] && [ "$(ls -l /mnt/$drive 2>&1 | grep 'Input/output error')" = "" ]; then
      curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "'$TELEGRAM_CHATID'", "text": "'$drive' Remounted", "disable_notification": true}' 'https://api.telegram.org/bot'$TELEGRAM_BOT_TOKEN'/sendMessage'
    else
      if [ "$(who | grep pts)" ]; then
        wall "$drive down! Not rebooting since ssh session exists!"
      else
        wall "Rebooting since ssh session does not exist!"
        curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "'$TELEGRAM_CHATID'", "text": "Rebooting '$(echo $HOSTNAME | cut -d . -f 1 | tr '[:lower:]' '[:upper:]')' due to IO error in '$drive'", "disable_notification": true}' 'https://api.telegram.org/bot'$TELEGRAM_BOT_TOKEN'/sendMessage'
        curl -X POST -H 'Content-Type: application/json' -d '{"seconds": "5"}' 'http://fig.lan:8123/api/webhook/'$(echo $HOSTNAME | cut -d . -f 1)'reboot'
      fi
    fi
  fi
done
EOF
)


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
  if [ -z "$(find -H /var/lib/apt/lists -maxdepth 0 -mmin 30)" ]; then
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
    localectl set-locale $LOCALE >/dev/null 2>&1 &&
      echo "LC_ALL=$LOCALE" >> /etc/environment &&
      echo "$LOCALE UTF-8" >> /etc/locale.gen &&
      echo "LANG=$LOCALE" > /etc/locale.conf &&
      locale-gen $LOCALE >/dev/null 2>&1 &
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
    echo -e "[Unit]\nDescription=Notify on system startup\nAfter=network-online.target\n\n[Service]\nUser=pi\nExecStart=curl -X POST -H 'Content-Type: application/json' -d '{\"chat_id\": \"$TELEGRAM_CHATID\", \"text\": \""$(echo $HOSTNAME | cut -d . -f 1 | tr '[:lower:]' '[:upper:]')" rebooted\", \"disable_notification\": true}' 'https://api.telegram.org/bot"$TELEGRAM_BOT_TOKEN"/sendMessage'\nRestartSec=5\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target" > /lib/systemd/system/notifyonstartup.service && \
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
  if [ $(raspi-config nonint get_config_var arm_freq /boot/firmware/config.txt) = $ARM_FREQUENCY ]; then
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
      echo -e "#Acquire::http::Proxy \"http://nas2.lan:3142\";\n#Acquire::https::Proxy \"false\";" > /etc/apt/apt.conf.d/00proxy &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  else
    print_not_required
  fi
}


setup_cron() {
  printf "   \e[34m•\e[0m Setting up cron... "
  if [ -f /var/spool/cron/crontabs/pi ]; then
    print_already
  else
    (echo "") | crontab -u pi - &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


mount_usb_drives() {
  for drive in $USB_DRIVES; do
    printf "   \e[34m•\e[0m Mounting USB drive: $drive... "
    fs_type="$(blkid | grep $drive | head -1)"
    fs_type="${fs_type#*TYPE=\"}"
    fs_type="${fs_type%%\"*}"
    if [ "$(blkid | grep $drive)" = "" ]; then
      print_notexist
    elif [ "$(mount | grep /mnt/$drive)" != "" ] || [ "$(grep /mnt/$drive /etc/fstab)" != "" ]; then
      print_already
    else
      mkdir -p /mnt/$drive && \
      touch /mnt/$drive/USB_NOT_MOUNTED && \
      echo "LABEL=$drive  /mnt/$drive  $fs_type  defaults,nofail,noatime  0  0" >> /etc/fstab && \
        mount -a >/dev/null 2>&1 && \
        chown pi:pi /mnt/$drive &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
  for drive in $USB_DRIVES; do
    printf "   \e[34m•\e[0m Setting up btrfs data scrubbing: $drive... "
    fs_type="$(blkid | grep $drive | head -1)"
    fs_type="${fs_type#*TYPE=\"}"
    fs_type="${fs_type%%\"*}"
    if [ "$(blkid | grep $drive)" = "" ]; then
      print_notexist
    elif [ "$fs_type" != "btrfs" ]; then
      print_not_required
    elif [ "$(crontab -u pi -l | grep 'sudo /mnt/'$drive'/scrub.sh')" != "" ]; then
      print_already
    else
      (crontab -u pi -l && echo "0 0 * * * sudo /mnt/$drive/scrub.sh") | crontab -u pi - &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
  for drive in $USB_DRIVES; do
    printf "   \e[34m•\e[0m Setting up btrfs snapshots: $drive... "
    fs_type="$(blkid | grep $drive | head -1)"
    fs_type="${fs_type#*TYPE=\"}"
    fs_type="${fs_type%%\"*}"
    if [ "$fs_type" != "btrfs" ]; then
      print_notexist
    elif [ "$(crontab -u pi -l | grep 'sudo btrfs subvolume snapshot /mnt/'$drive' /mnt/'$drive'/.snapshots/@GMT')" != "" ]; then
      print_already
    else
      (crontab -u pi -l && echo "30 0 * * * sudo btrfs subvolume snapshot /mnt/$drive /mnt/$drive/.snapshots/@GMT_\`date -u +\\%Y.\\%m.\\%d-\\%H.\\%M.\\%S\`") | crontab -u pi - &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
  for drive in $USB_DRIVES; do
    printf "   \e[34m•\e[0m Setting up backup jobs: $drive... "
    script_file="${backup_script[$drive]}"
    if [ "$(blkid | grep $drive)" = "" ]; then
      print_notexist
    elif [ "$(crontab -u pi -l | grep '/mnt/'$drive'/'$script_file)" != "" ]; then
      print_already
    else
      (crontab -u pi -l && echo "${backup_schedule[$drive]} sudo /mnt/$drive/$script_file") | crontab -u pi - &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
}


relocate_apt_cache() {
  printf "   \e[34m•\e[0m Relocating apt cache... "
  if [ "$(grep "Dir::Cache /mnt/$USB_DATA_DEVICE/.data/apt-cache;" /etc/apt/apt.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    mkdir -p /mnt/$USB_DATA_DEVICE/.data/apt-cache && \
      echo "Dir::Cache /mnt/$USB_DATA_DEVICE/.data/apt-cache;" > /etc/apt/apt.conf &
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
    echo -e "PasswordAuthentication no\nMatch address 192.168.88.0/24\n    PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
      systemctl restart ssh.service &
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


setup_google_backup() {
  printf "   \e[34m•\e[0m Setting up Google Backup... "
  if [ "$(crontab -u pi -l | grep backup-gdrive)" != "" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq rclone >/dev/null 2>&1 && \
      sudo -u pi mkdir -p /home/pi/.config/rclone
      cp /mnt/$USB_DATA_DEVICE/Ameer/rclone.conf /home/pi/.config/rclone/rclone.conf && \
      chown pi:pi /home/pi/.config/rclone/rclone.conf && \
      (crontab -u pi -l && echo -e "0 2 * * * /mnt/$USB_DATA_DEVICE/Ameer/backup-gdrive-ameer.sh\n4 2 * * * /mnt/$USB_DATA_DEVICE/Ameer/backup-gdriveshared-ameer.sh\n7 2 * * * /mnt/$USB_DATA_DEVICE/Aani/backup-gdrive-aani.sh\n10 2 * * * /mnt/$USB_DATA_DEVICE/Nimra/backup-gdrive-nimra.sh\n13 2 * * * /mnt/$USB_DATA_DEVICE/Ameer/backup-gphotos-ameer.sh\n16 2 * * * /mnt/$USB_DATA_DEVICE/Aani/backup-gphotos-aani.sh\n19 2 * * * /mnt/$USB_DATA_DEVICE/Nimra/backup-gphotos-nimra.sh") | crontab -u pi - &
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
    DEBIAN_FRONTEND=noninteractive apt-get install -yq git >/dev/null 2>&1 && \
      (crontab -u pi -l && echo "0 3 * * * /mnt/$USB_DATA_DEVICE/Ameer/gitbackup/gitbackup.sh") | crontab -u pi - &
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
      echo -e "[$drive]\npath = /mnt/$drive\ncomment = $drive\nlist = yes\nhosts allow = 192.168.88.1/24,127.0.0.1,100.82.10.102" >> /etc/rsyncd.conf && \
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
  SAMBA_VFS_MODULES_REQUIRED=false
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
  printf "   \e[34m•\e[0m Adding samba user... "
  if [ "$(pdbedit -L | grep ^pi:)" != "" ]; then
    print_already
  else
    echo -e "$SAMBA_PASSWORD\n$SAMBA_PASSWORD" | smbpasswd -s -a pi >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  for drive in $USB_DRIVES; do
    printf "   \e[34m•\e[0m Setting up samba share for $drive... "
    fs_type="$(blkid | grep $drive | head -1)"
    fs_type="${fs_type#*TYPE=\"}"
    fs_type="${fs_type%%\"*}"
    if [ "$fs_type" = "btrfs" ]; then
      SAMBA_VFS_MODULES_REQUIRED=true
    fi
    if [ "$(blkid | grep $drive)" = "" ]; then
      print_notexist
    elif [ "$(grep /mnt/$drive /etc/samba/smb.conf)" != "" ]; then
      print_already
    else
      if [ "$fs_type" = "btrfs" ]; then
        echo -e "[$drive]\n    path = /mnt/$drive\n    read only = no\n    writable = yes\n    browsable = yes\n    guest ok = no\n    create mask = 0755\n    directory mask = 0777\n    force user = pi\n    force group = pi\n    vfs objects = shadow_copy2\n    shadow:format = @GMT_%Y.%m.%d-%H.%M.%S\n    shadow:sort = desc\n    shadow:snapdir = .snapshots\n" >> /etc/samba/smb.conf && \
          systemctl restart smbd.service &
        bg_pid=$!
        show_progress $bg_pid
        wait $bg_pid
        assert_status
      else
        echo -e "[$drive]\n    path = /mnt/$drive\n    read only = no\n    writable = yes\n    browsable = yes\n    guest ok = no\n    create mask = 0755\n    directory mask = 0777\n    force user = pi\n    force group = pi" >> /etc/samba/smb.conf && \
          systemctl restart smbd.service &
        bg_pid=$!
        show_progress $bg_pid
        wait $bg_pid
        assert_status
      fi
    fi
  done
  printf "   \e[34m•\e[0m Installing samba vfs modules... "
  if [ $SAMBA_VFS_MODULES_REQUIRED = true ]; then
    if [ "$(dpkg-query -W -f='${Status}' samba-vfs-modules 2>/dev/null)" = "install ok installed" ]; then
      print_already
    else
      DEBIAN_FRONTEND=noninteractive apt-get install -yq samba-vfs-modules >/dev/null 2>&1 && \
        systemctl restart smbd.service &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  else
    print_not_required
  fi
}


setup_aria2() {
  printf "   \e[34m•\e[0m Installing aria2... "
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
  if [ -d /mnt/$USB_DATA_DEVICE/.data/aria2 ]; then
    print_already
  else
    sudo -u pi mkdir -p /mnt/$USB_DATA_DEVICE/.data/aria2 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 session file... "
  if [ -f /mnt/$USB_DATA_DEVICE/.data/aria2/session ]; then
    print_already
  else
    sudo -u pi touch /mnt/$USB_DATA_DEVICE/.data/aria2/session &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 configuration file... "
  if [ -f /mnt/$USB_DATA_DEVICE/.data/aria2/aria2.conf ]; then
    print_already
  else
    echo -e "daemon=true\ndir=/mnt/$USB_DATA_DEVICE/aria2\nfile-allocation=prealloc\ncontinue=true\nsave-session=/mnt/$USB_DATA_DEVICE/.data/aria2/session\ninput-file=/mnt/$USB_DATA_DEVICE/.data/aria2/session\nsave-session-interval=10\nforce-save=true\nmax-connection-per-server=10\nenable-rpc=true\nrpc-listen-all=true\nrpc-secret=$ARIA2_RPC_TOKEN\nrpc-listen-port=6800\nrpc-allow-origin-all=true\non-download-complete=/mnt/$USB_DATA_DEVICE/.data/aria2/hook-complete.sh\non-bt-download-complete=/mnt/$USB_DATA_DEVICE/.data/aria2/hook-complete.sh\non-download-error=/mnt/$USB_DATA_DEVICE/.data/aria2/hook-error.sh\nmax-overall-download-limit=200K\nmax-concurrent-downloads=1\nquiet=true\nseed-time=0" | sudo -u pi tee /mnt/$USB_DATA_DEVICE/.data/aria2/aria2.conf > /dev/null &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 hook-complete file... "
  if [ -f /mnt/$USB_DATA_DEVICE/.data/aria2/hook-complete.sh ]; then
    print_already
  else
    echo -e "#"'!'"/bin/sh\ncurl -X POST -H 'Content-Type: application/json' -d '{\"chat_id\": \"$TELEGRAM_CHATID\", \"text\": \"✅ Download Complete: '\"$3\"'\", \"disable_notification\": false}' 'https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage'\nrm \"\$3.aria2\"" | sudo -u pi tee /mnt/$USB_DATA_DEVICE/.data/aria2/hook-complete.sh > /dev/null && \
      chmod +x /mnt/$USB_DATA_DEVICE/.data/aria2/hook-complete.sh &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 hook-error file... "
  if [ -f /mnt/$USB_DATA_DEVICE/.data/aria2/hook-error.sh ]; then
    print_already
  else
    echo -e "#"'!'"/bin/sh\ncurl -X POST -H 'Content-Type: application/json' -d '{\"chat_id\": \"$TELEGRAM_CHATID\", \"text\": \"❌ Download Error: '\"$3\"'\", \"disable_notification\": false}' 'https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage'\nrm \"\$3.aria2\"" | sudo -u pi tee /mnt/$USB_DATA_DEVICE/.data/aria2/hook-error.sh > /dev/null && \
      chmod +x /mnt/$USB_DATA_DEVICE/.data/aria2/hook-error.sh &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating aria2 download directory... "
  if [ -d /mnt/$USB_DATA_DEVICE/aria2 ]; then
    print_already
  else
    sudo -u pi mkdir -p /mnt/$USB_DATA_DEVICE/aria2 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Configuring aria2 autostart... "
  if [ -f /lib/systemd/system/aria2.service ]; then
    print_already
  else
    echo -e "[Unit]\nDescription=a lightweight multi-protocol & multi-source command-line download utility\nConditionPathExists=/mnt/$USB_DATA_DEVICE/.data/aria2/aria2.conf\nConditionFileIsExecutable=/usr/bin/aria2c\nAfter=network-online.target mnt-$USB_DATA_DEVICE.mount\nDocumentation=man:aria2c(1)\n\n[Service]\nType=forking\nUser=pi\nExecStart=/usr/bin/aria2c --conf-path=/mnt/$USB_DATA_DEVICE/.data/aria2/aria2.conf\nRestart=always\nRestartSec=1\n\n[Install]\nWantedBy=multi-user.target" > /lib/systemd/system/aria2.service && \
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
    cat /mnt/$USB_DATA_DEVICE/cert/nas1.pem /mnt/$USB_DATA_DEVICE/cert/nas1.key > /etc/lighttpd/server.pem &
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
  if [ -d /mnt/$USB_DATA_DEVICE/.data/webui-aria2 ]; then
    print_already
  else
    git clone --quiet --depth=1 https://github.com/ziahamza/webui-aria2 /mnt/$USB_DATA_DEVICE/.data/webui-aria2 2>/dev/null &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Setting up aria2 webui... "
  if [ -d /var/www/html/webui-aria2 ]; then
    print_already
  else
    ln -s /mnt/$USB_DATA_DEVICE/.data/webui-aria2/docs /var/www/html/webui-aria2 >/dev/null 2>&1 &
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
  printf "   \e[34m•\e[0m Installing rsyslog... "
  if [ "$(dpkg-query -W -f='${Status}' rsyslog 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq rsyslog >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Setting up remote syslog... "
  if [ "$(grep 'fig.lan' /etc/rsyslog.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    echo "*.* @fig.lan" >> /etc/rsyslog.conf &&
    systemctl restart rsyslog.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_usb_checker() {
  usb_checker_script_location="/home/pi/checker.sh"
  printf "   \e[34m•\e[0m Adding USB checker... "
  if [ -f "$usb_checker_script_location" ]; then
    print_already
  else
    if [ "$(grep usb /etc/fstab)" ]; then
      echo "$usb_checker_script" > "$usb_checker_script_location" && \
        chown pi:pi "$usb_checker_script_location" && \
        chmod +x "$usb_checker_script_location" &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    else
      print_not_required
    fi
  fi
  printf "   \e[34m•\e[0m Setting up USB checker task... "
  if [ "$(crontab -u pi -l | grep $usb_checker_script_location)" != "" ]; then
    print_already
  else
    if [ "$(grep usb /etc/fstab)" ]; then
      (crontab -u pi -l && echo "* * * * * $usb_checker_script_location") | crontab -u pi - &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    else
      print_not_required
    fi
  fi
}


install_tailscale() {
  printf "   \e[34m•\e[0m Installing Tailscale... "
  if [ ! -f /mnt/$USB_DATA_DEVICE/.data/tailscale/tailscaled.state ]; then
    print_not_required
  else
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
      tailscale down --accept-risk=lose-ssh && \
        systemctl stop tailscaled.service && \
        cp /mnt/$USB_DATA_DEVICE/.data/tailscale/tailscaled.state /var/lib/tailscale/tailscaled.state && \
        systemctl start tailscaled.service &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
    printf "   \e[34m•\e[0m Fixing up Tailscale log level... "
    if [ "$(grep 'LogLevelMax' /etc/systemd/system/tailscaled.service.d/override.conf 2>/dev/null)" != "" ]; then
      print_already
    else
      mkdir -p /etc/systemd/system/tailscaled.service.d && \
        echo -e "[Service]\nLogLevelMax=notice" > /etc/systemd/system/tailscaled.service.d/override.conf && \
        systemctl daemon-reload && \
        systemctl restart tailscaled.service &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
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


prepare_overlayfs() {
  printf "   \e[34m•\e[0m Preparing system for overlayroot... "
  if [ "$(dpkg-query -W -f='${Status}' busybox-static 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq busybox-static >/dev/null 2>&1 &
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
      sed -i 's/^overlayroot=""/overlayroot="tmpfs:swap=1,recurse=0"/g' /etc/overlayroot.conf && \
        mkdir -p /etc/systemd/system.conf.d && \
        echo "DefaultEnvironment=\"LIBMOUNT_FORCE_MOUNT2=always\"" > /etc/systemd/system.conf.d/overlayfs.conf &
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
    systemctl stop plexmediaserver.service && \
      rm -rf /var/lib/plexmediaserver/Library
      ln -s /mnt/$USB_DATA_DEVICE/.data/Plex/Library /var/lib/plexmediaserver/Library && \
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
    mkdir -p /etc/systemd/system/plexmediaserver.service.d && \
      echo -e "[Unit]\nAfter=network.target network-online.target mnt-$USB_DATA_DEVICE.mount\nConditionPathExists=/mnt/$USB_DATA_DEVICE/.data/Plex" > /etc/systemd/system/plexmediaserver.service.d/override.conf && \
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
    if [ $(cat /etc/os-release | grep Ubuntu) ]; then
      distro="ubuntu"
    else
      distro="debian"
    fi
    curl -fsSL https://download.docker.com/linux/$distro/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
      echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$distro "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null &
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
    systemctl stop docker.service 2>/dev/null && \
      rm -rf /var/lib/docker && \
      ln -s /mnt/$USB_DATA_DEVICE/docker/docker /var/lib/docker && \
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
    mkdir -p /etc/systemd/system/docker.service.d && \
      echo -e "[Unit]\nAfter=network-online.target docker.socket firewalld.service containerd.service time-set.target mnt-$USB_DATA_DEVICE.mount\nConditionPathExists=/mnt/$USB_DATA_DEVICE/docker" > /etc/systemd/system/docker.service.d/override.conf && \
      systemctl daemon-reload && \
      systemctl restart docker.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


install_keepalived() {
  printf "   \e[34m•\e[0m Installing keepalived... "
  if [ "$(dpkg-query -W -f='${Status}' keepalived 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq keepalived >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Setting up keepalived... "
  if [ -f /etc/keepalived/keepalived.conf ]; then
    print_already
  else
    cp /mnt/$USB_DATA_DEVICE/docker/keepalived/keepalived.conf /etc/keepalived/keepalived.conf && \
      systemctl restart keepalived.service &
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
  printf "   \e[34m•\e[0m Creating symlinks to external storage... "
  if [ -L /var/spool/cups ]; then
    print_already
  else
    rm -rf /var/spool/cups && \
      ln -s /mnt/$USB_DATA_DEVICE/.data/cups /var/spool/cups && \
      systemctl restart cups.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_cups_ssl() {
  printf "   \e[34m•\e[0m Setting up cups ssl certificates... "
  if [ -L /etc/cups/ssl/printer.lan.crt ] && [ -L /etc/cups/ssl/printer.lan.key ]; then
    print_already
  else
    rm /etc/cups/ssl/printer.lan.crt 2>/dev/null; \
      rm /etc/cups/ssl/printer.lan.key 2>/dev/null; \
      ln -s /mnt/$USB_DATA_DEVICE/docker/tls/printer.crt /etc/cups/ssl/printer.lan.crt && \
      ln -s /mnt/$USB_DATA_DEVICE/docker/tls/printer.key /etc/cups/ssl/printer.lan.key && \
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


install_avahi() {
  printf "   \e[34m•\e[0m Installing avahi... "
  if [ "$(dpkg-query -W -f='${Status}' avahi-utils 2>/dev/null)" = "install ok installed" ]; then
    print_already
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -yq avahi-utils >/dev/null 2>&1 &
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
  if [ -d /var/lib/scanservjs ]; then
    print_already
  else
    curl -s https://raw.githubusercontent.com/sbs20/scanservjs/master/bootstrap.sh | bash -s -- -v latest >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Creating symlinks to external storage... "
  if [ -L /var/lib/scanservjs/output ]; then
    print_already
  else
    rm -rf /var/lib/scanservjs/output && \
      ln -s /mnt/$USB_DATA_DEVICE/scans /var/lib/scanservjs/output && \
      systemctl restart scanservjs.service &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


fixup_dns_nameserver () {
  printf "   \e[34m•\e[0m Fixing up DNS nameserver... "
  if [ "$(grep 'prepend domain-name-servers 192.168.88.1;' /etc/dhcp/dhclient.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    echo "prepend domain-name-servers 192.168.88.1;" >> /etc/dhcp/dhclient.conf &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


if [ "$(systemd-detect-virt)" = "qemu" ]; then
  printf "  \e[34m○\e[0m Running QEMU Specific Setup:\n"
  fixup_dns_nameserver
fi

#### Tasks to run
printf "  \e[34m○\e[0m Running Common Setup:\n"
update_apt
setup_hostname
setup_locale
setup_timezone
notify_on_startup
setup_ssh_keyfile
setup_apt-cacher-ng
setup_cron
mount_usb_drives
relocate_apt_cache
disable_password_login
setup_passwordless_sudo
add_zram
setup_overlayroot_notice
setup_rsync_daemon
setup_samba_shares
disable_swap
setup_remote_syslog
setup_usb_checker
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
  install_keepalived
fi

if [ "$HOSTNAME" = "printer.lan" ]; then
  printf "\n  \e[34m○\e[0m Running Print Server Specific Setup:\n"
  install_cups
  setup_cups_ssl
  install_ppds
  add_printers
  install_avahi
  setup_scan_server
  install_docker
  install_keepalived
  prepare_overlayfs
fi

if [ "$HOSTNAME" = "fig.lan" ]; then
  printf "\n  \e[34m○\e[0m Running Fig Specific Setup:\n"
  install_docker
fi

if [ "$HOSTNAME" = "apricot.lan" ]; then
  printf "\n  \e[34m○\e[0m Running Apricot Specific Setup:\n"
  install_docker
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