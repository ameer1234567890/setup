#!/bin/sh

REBOOT_REQUIRED=false
ARIA2_OK=false
GIT_OK=false

clear
echo ""
echo " ##############################################################################"
echo " ##                                                                          ##"
echo " ##                               ROUTER SETUP                               ##"
echo " ##                                                                          ##"
echo " ##                              by Ameer Dawood                             ##"
echo " ##                                                                          ##"
echo " ##         This script runs my customized setup process on OpenWrt          ##"
echo " ##                                                                          ##"
echo " ##############################################################################"
echo ""


kill_tools() {
  tools="opkg tar wget git"
  printf "\n\n User cancelled!\n"
  for tool in $tools; do
    if [ "$(pidof "$tool")" != "" ]; then
      printf " Killing %s... " "$tool"
    	killall "$tool" >/dev/null 2>&1
      assert_status
    fi
  done

  temp_files="opkgstatus.txt crontab.txt"
  for file in $temp_files; do
    if [ -f "$file" ]; then
      printf " Deleting temporary file %s... " "$file"
      rm "$file" >/dev/null 2>&1
      assert_status
    fi
  done
  
  echo ""
  exit 0
}


trap kill_tools 1 2 3 15


help() {
  echo ""
  echo "Usage: $0 -k KEY -t TOKEN -s API_KEY"
  echo ""
  echo "Run my customized setup process on OpenWrt"
  echo ""
  printf "\t-k KEY\t\tSlack webhook key\n"
  printf "\t-t TOKEN\tRPC token to be used in aria2\n"
  printf "\t-s API_KEY\tThingSpeak API key\n"
  printf "\t-h\t\tshow help message and exit\n"
  echo ""
  exit
}


while getopts "k:t:s:h" opt; do
  case "$opt" in
    k ) SLACK_WEBHOOK_KEY="$OPTARG" ;;
    t ) ARIA2_RPC_TOKEN="$OPTARG" ;;
    s ) THINGSPEAK_API_KEY="$OPTARG" ;;
    h ) help ;;
    ? ) help ;;
  esac
done


if [ -z "$SLACK_WEBHOOK_KEY" ] || [ -z "$ARIA2_RPC_TOKEN" ]; then
  echo "Some or all of the parameters are empty"
  help
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
print_required() { printf "\e[32mRequired!\e[0m\n"; }


showoff() {
  # this is just a showoff to the user that some processing is happening in the background.
  # I do this since busybox's sleep does not support frctional seconds and 1 second is too long.

  # here we collect return code for last command, prior to calling showoff, which most probably
  # is the important command that we ran
  status=$?
  i=0;
  while [ $i -le 300 ]; do
    echo "" >/dev/null
    i=$(( i + 1 ))
  done
  # here we return the return code collected from the last command, prior to
  # calling showoff, so that the next command in the chain (most probably assert_status) gets
  # its required return code
  return $status
}


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
    showoff
  done
}


update_opkg() {
  printf "   \e[34m•\e[0m Running opkg update... "
  opkg update >/dev/null 2>&1 &
  bg_pid=$!
  show_progress $bg_pid
  wait $bg_pid
  assert_status
}


# check if opkg update is required, and perform update if required
printf " \e[34m•\e[0m Checking if opkg update is required... "
opkg find zsh > opkgstatus.txt 2>/dev/null & # replace zsh with any tool that is definitely not installed
bg_pid=$!
show_progress $bg_pid
wait $bg_pid
status=$?
if [ $status = 0 ]; then
  if [ "$(cat opkgstatus.txt 2>/dev/null)" != "" ]; then
    printf "\e[36mNo!\e[0m\n"
  else
    printf "\e[32mYes!\e[0m\n"
    update_opkg
  fi
else
  printf "\e[91mFailed!\e[0m\n"
  update_opkg
fi
rm opkgstatus.txt >/dev/null 2>&1


notify_on_startup() {
  printf " \e[34m•\e[0m Notify on Startup:\n"
  printf "   \e[34m•\e[0m Setting up notification via Slack, on router startup... "
  if [ "$(grep -F "https://hooks.slack.com/services/" /etc/rc.local 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    sed -i -e '$i \sleep 14 && curl -X POST --data-urlencode "payload={\\\"channel\\\": \\\"#general\\\", \\\"username\\\": \\\"NotifyBot\\\", \\\"text\\\": \\\"NAS1 rebooted.\\\", \\\"icon_emoji\\\": \\\":slack:\\\"}" https://hooks.slack.com/services/'"$SLACK_WEBHOOK_KEY"' &\n' /etc/rc.local >/dev/null 2>&1
    showoff
    assert_status
  fi
}


install_openssh_sftp_server() {
  printf " \e[34m•\e[0m Install SFTP Server:\n"
  printf "   \e[34m•\e[0m Installing OpenSSH SFTP server... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F "openssh-sftp-server")" != "" ]; then
    showoff
    print_already
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install openssh-sftp-server >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


set_nano_default() {
  printf " \e[34m•\e[0m Install and Setup Nano:\n"
  proceed=false
  printf "   \e[34m•\e[0m Installing nano... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F "nano")" != "" ]; then
    showoff
    print_already
    proceed=true
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install nano >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status && proceed=true
  fi

  if [ $proceed = true ]; then
    printf "   \e[34m•\e[0m Setting nano as default editor for future sessions... "
    if [ "$(grep -F "export EDITOR=nano" /etc/profile 2>/dev/null)" != "" ]; then
      showoff
      print_already
    else
      showoff
      sed -i '$ a \\nexport EDITOR=nano\n' /etc/profile >/dev/null 2>&1
      assert_status
    fi

    printf "   \e[34m•\e[0m Setting nano as default editor for current session... "
    if [ "$(env | grep -F "EDITOR=nano")" != "" ]; then
      showoff
      print_already
    else
      showoff
      printf "\e[33mNot supported! Please set manually by entering \"export EDITOR=nano\" in the terminal!\e[0m\n"
    fi
  fi
}


setup_usb_storage() {
  printf " \e[34m•\e[0m Setup USB Storage:\n"
  proceed=true
  packages="kmod-usb-core usbutils kmod-usb-storage kmod-fs-ext4 block-mount"
  for package in $packages; do
    printf "   \e[34m•\e[0m Installing required packages for USB storage (%s)... " "$package"
    if [ "$(opkg list-installed 2>/dev/null | grep -F "$package")" != "" ]; then
      showoff
      print_already
    elif [ -f /var/lock/opkg.lock ]; then
      showoff
      print_opkg_busy
      proceed=false
    else
      opkg install "$package" >/dev/null 2>&1 &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status || proceed=false
    fi
  done

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating mount directory... "
    if [ -d /mnt/usb1 ]; then
      showoff
      print_already
      proceed=true
    else
      showoff
      mkdir /mnt/usb1 >/dev/null 2>&1
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Touching empty file which identifies mount status... "
    if [ -f /mnt/usb1/USB_NOT_MOUNTED ] || [ "$(mount | grep -F "/mnt/usb1")" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      showoff
      touch /mnt/usb1/USB_NOT_MOUNTED >/dev/null 2>&1
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Test mounting in current session... "
    if [ "$(mount | grep -F "/mnt/usb1")" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      mount -t ext4 -o rw,async,noatime /dev/sda1 /mnt/usb1 >/dev/null 2>&1
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    printf "   \e[34m•\e[0m Setting up persistent mount config... "
    if [ "$(grep -F "/mnt/usb1" /etc/config/fstab)" != "" ]; then
      showoff
      print_already
    else
      sed -i '$ a \\nconfig mount\n\toption enabled '"'1'"'\n\toption device '"'/dev/sda1'"'\n\toption target '"'/mnt/usb1'"'\n\toption fstype '"'ext4'"'\n\toption options '"'async,noatime,rw'"'\n' /etc/config/fstab >/dev/null 2>&1
      assert_status
    fi
  fi
}


setup_samba() {
  printf " \e[34m•\e[0m Install and Startup Samba:\n"
  proceed=true
  samba_restart_required=false
  printf "   \e[34m•\e[0m Installing samba36-server... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F samba36-server)" != "" ]; then
    showoff
    print_already
    proceed=true
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install samba36-server >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status && proceed=true
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting up samba config... "
    if [ "$(grep -F "option 'path' '/mnt/usb1'" /etc/config/samba)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      printf "config samba\n\toption workgroup 'WORKGROUP'\n\toption homes '1'\n\toption name 'nas1'\n\toption description 'nas1'\n\nconfig 'sambashare'\n\toption 'name' 'usb1'\n\toption 'path' '/mnt/usb1'\n\toption 'users' 'user'\n\toption 'guest_ok' 'yes'\n\toption 'create_mask' '0644'\n\toption 'dir_mask' '0777'\n\toption 'read_only' 'no'\n" > /etc/config/samba 2>/dev/null
      showoff
      assert_status && proceed=true
      samba_restart_required=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting up smb.conf.template... "
    if [ "$(grep -F "min protocol = SMB2" /etc/samba/smb.conf.template)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      sed -i '$ a \\n\tmin protocol = SMB2\n' /etc/samba/smb.conf.template >/dev/null 2>&1
      showoff
      assert_status && proceed=true
      samba_restart_required=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting up samba system user... "
    if [ "$(grep -F "user:" /etc/passwd)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      sed -i '$ a \\nuser:x:501:501:user:/home/user:/bin/ash\n' /etc/passwd >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting up password for samba system user... "
    if [ "$(grep -F "user:x:" /etc/passwd)" = "" ]; then
      showoff
      print_already
      proceed=true
    else
      showoff
      printf "\e[33mNot supported! Please set a password manually by entering \"passwd user\" in the terminal!\e[0m\n"
      proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting up user & password for smb user... "
    if [ "$(grep -F "user:501:" /etc/samba/smbpasswd)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      showoff
      printf "\e[33mNot supported! Please set a password manually by entering \"smbpasswd -a user\" in the terminal!\e[0m\n"
      proceed=true
    fi
  fi

  printf "   \e[34m•\e[0m Restarting samba... "
  if [ $samba_restart_required = true ]; then
    /etc/init.d/samba restart >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  else
    print_not_required
  fi
}


make_samba_wan_accessible() {
  printf " \e[34m•\e[0m Making Samba Web Accessible:\n"
  samba_restart_required=false
  printf "   \e[34m•\e[0m Making samba accessible from WAN... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F "samba36-server")" != "" ]; then
    if [ "$(grep -F "bind interfaces only = no" /etc/samba/smb.conf.template)" != "" ]; then
      showoff
      print_already
    else
      sed -i '/\tbind interfaces only = yes/ c\ \tbind interfaces only = no' /etc/samba/smb.conf.template >/dev/null 2>&1
      showoff
      assert_status
      samba_restart_required=true
    fi
  else
    printf "\e[33mSamba not installed!\e[0m\n"
  fi

  printf "   \e[34m•\e[0m Restarting samba... "
  if [ $samba_restart_required = true ]; then
    /etc/init.d/samba restart >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  else
    print_not_required
  fi
}


setup_rsync() {
  printf " \e[34m•\e[0m Install and Setup Rsync:\n"
  proceed=false
  printf "   \e[34m•\e[0m Installing rsync... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F "rsync")" != "" ]; then
    showoff
    print_already
    proceed=true
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install rsync >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status && proceed=true
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Configuring rsync... "
    if [ "$(grep -F "path = /mnt/usb1" /etc/rsyncd.conf 2>/dev/null)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      printf 'pid file = /var/run/rsyncd.pid\nlog file = /var/log/rsyncd.log\nlock file = /var/run/rsync.lock\nuse chroot = no\nuid = user\ngid = 501\nread only = no\n\n[usb1]\npath = /mnt/usb1\ncomment = NAS of Ameer\nlist = yes\nhosts allow = 192.168.100.1/24' > /etc/rsyncd.conf 2>/dev/null
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Starting up rsync daemon... "
    if [ "$(pgrep -f "rsync --daemon" 2>/dev/null)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      rsync --daemon >/dev/null 2>&1
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    printf "   \e[34m•\e[0m Setting up rsync daemon startup config... "
    if [ "$(grep -F "rsync --daemon" /etc/rc.local 2>/dev/null)" != "" ]; then
      showoff
      print_already
    else
      sed -i -e '$i \rsync --daemon &\n' /etc/rc.local >/dev/null 2>&1
      assert_status
    fi
  fi
}


disable_dropbear_password_auth() {
  printf " \e[34m•\e[0m Disable Password Auth in Dropbear:\n"
  dropbear_restart_required=false
  printf "   \e[34m•\e[0m Disabling password authentication in dropbear... "
  if [ "$(uci get dropbear.@dropbear[0].PasswordAuth)" = "off" ]; then
    showoff
    print_already
  else
    uci set dropbear.@dropbear[0].PasswordAuth='off' >/dev/null 2>&1
    uci commit dropbear >/dev/null 2>&1
    showoff
    assert_status
    dropbear_restart_required=true
  fi

  printf "   \e[34m•\e[0m Restarting dropbear... "
  if [ $dropbear_restart_required = true ]; then
    /etc/init.d/dropbear restart >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  else
    print_not_required
  fi
}


setup_remote_ssh() {
  printf " \e[34m•\e[0m Setup Remote SSH:\n"
  proceed=false
  printf "   \e[34m•\e[0m Installing autossh... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F "autossh")" != "" ]; then
    showoff
    print_already
    proceed=true
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install autossh >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status && proceed=true
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating serveo service... "
    if [ -f /etc/init.d/serveo ]; then
      showoff
      print_already
      proceed=true
    else
      printf "#!/bin/sh /etc/rc.common\n\nSTART=99\n\nstart() {\n\techo \"Starting serveo service...\"\n\t/usr/sbin/autossh -M 22 -y -R ameer:22:localhost:22 serveo.net < /dev/ptmx &\n}\n\nstop() {\n\techo \"Stopping serveo service...\"\n\tpids=\"\$(pgrep -f ameer)\"\n\tfor pid in \$pids; do\n\t\t/bin/kill \"\$pid\"\n\tdone\n}\n\nrestart() {\n\tstop\n\tstart\n}\n" > /etc/init.d/serveo 2>/dev/null
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting executable permissions serveo service... "
    if [ "$(find /etc/init.d/serveo -perm -u=x 2>/dev/null)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      chmod +x /etc/init.d/serveo >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Starting serveo service... "
    if [ "$(pgrep -f "ameer")" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      /etc/init.d/serveo start >/dev/null 2>&1 &
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    printf "   \e[34m•\e[0m Enabling autostart of serveo service... "
    # shellcheck disable=SC2010
    if [ "$(ls -l /etc/rc.d | grep -F "../init.d/serveo")" != "" ]; then
      showoff
      print_already
    else
      /etc/init.d/serveo enable >/dev/null 2>&1
      showoff
      assert_status
    fi
  fi
}


setup_router_remote_http() {
  printf " \e[34m•\e[0m Setup Router Remote HTTP:\n"
  proceed=false
  printf "   \e[34m•\e[0m Installing autossh... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F "autossh")" != "" ]; then
    showoff
    print_already
    proceed=true
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install autossh >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status && proceed=true
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating gadhamoo service... "
    if [ -f /etc/init.d/gadhamoo ]; then
      showoff
      print_already
      proceed=true
    else
      printf "#!/bin/sh /etc/rc.common\n\nSTART=99\n\nstart() {\n\techo \"Starting gadhamoo service...\"\n\t/usr/sbin/autossh -M 80 -y -R gadhamoo:80:192.168.100.1:80 serveo.net < /dev/ptmx &\n}\n\nstop() {\n\techo \"Stopping gadhamoo service...\"\n\tpids=\"\$(pgrep -f gadhamoo)\"\n\tfor pid in \$pids; do\n\t\t/bin/kill \"\$pid\"\n\tdone\n}\n\nrestart() {\n\tstop\n\tstart\n}\n" > /etc/init.d/gadhamoo 2>/dev/null
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting executable permissions gadhamoo service... "
    if [ "$(find /etc/init.d/gadhamoo -perm -u=x 2>/dev/null)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      chmod +x /etc/init.d/gadhamoo >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Starting gadhamoo service... "
    if [ "$(pgrep -f "gadhamoo")" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      /etc/init.d/gadhamoo start >/dev/null 2>&1 &
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    printf "   \e[34m•\e[0m Enabling autostart of gadhamoo service... "
    # shellcheck disable=SC2010
    if [ "$(ls -l /etc/rc.d | grep -F "../init.d/gadhamoo")" != "" ]; then
      showoff
      print_already
    else
      /etc/init.d/gadhamoo enable >/dev/null 2>&1
      showoff
      assert_status
    fi
  fi
}


setup_aria2() {
  printf " \e[34m•\e[0m Install and Setup Aria2:\n"
  ARIA2_OK=false
  proceed=true
  packages="aria2 sudo curl"
  for package in $packages; do
    printf "   \e[34m•\e[0m Installing required packages for aria2 (%s)... " "$package"
    if [ "$(opkg list-installed 2>/dev/null | grep -F "$package")" != "" ]; then
      showoff
      print_already
    elif [ -f /var/lock/opkg.lock ]; then
      showoff
      print_opkg_busy
      proceed=false
    else
      opkg install "$package" >/dev/null 2>&1 &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status || proceed=false
    fi
  done

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating home directory for user... "
    if [ -d /home/user ]; then
      showoff
      print_already
      proceed=true
    else
      mkdir -p /home/user >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Assigning ownership of user's home directory to user... "
    if [ "$(find /home/user -maxdepth 0 -user user)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      chown user:501 /home/user >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating .aria2 directory... "
    if [ -d /home/user/.aria2 ]; then
      showoff
      print_already
      proceed=true
    else
      sudo -u user mkdir /home/user/.aria2 >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating aria2 session file... "
    if [ -f /home/user/.aria2/session ]; then
      showoff
      print_already
      proceed=true
    else
      sudo -u user touch /home/user/.aria2/session >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating aria2 configuration file... "
    if [ -f /home/user/.aria2/aria2.conf ]; then
      showoff
      print_already
      proceed=true
    else
      printf "daemon=true\ndir=/mnt/usb1/aria2\nfile-allocation=prealloc\ncontinue=true\nsave-session=/home/user/.aria2/session\ninput-file=/home/user/.aria2/session\nsave-session-interval=10\nforce-save=true\nmax-connection-per-server=10\nenable-rpc=true\nrpc-listen-all=true\nrpc-secret=%s\nrpc-listen-port=6800\nrpc-allow-origin-all=true\non-download-complete=/home/user/.aria2/hook-complete.sh\non-bt-download-complete=/home/user/.aria2/hook-complete.sh\non-download-error=/home/user/.aria2/hook-error.sh\nmax-overall-download-limit=20K\nmax-concurrent-downloads=1\n" "$ARIA2_RPC_TOKEN" 2>/dev/null | sudo -u user tee /home/user/.aria2/aria2.conf >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating aria2 hook-complete file... "
    if [ -f /home/user/.aria2/hook-complete.sh ]; then
      showoff
      print_already
      proceed=true
    else
      printf "#!/bin/sh\ncurl -X POST --data-urlencode \"payload={\\\"channel\\\": \\\"#general\\\", \\\"username\\\": \\\"aria2\\\", \\\"text\\\": \\\"Download complete: \$3\\\", \\\"icon_emoji\\\": \\\":slack:\\\"}\" https://hooks.slack.com/services/%s\n" "$SLACK_WEBHOOK_KEY" 2>/dev/null | sudo -u user tee /home/user/.aria2/hook-complete.sh >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting executable permissions hook-complete file... "
    if [ "$(find /home/user/.aria2/hook-complete.sh -perm -u=x 2>/dev/null)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      chmod +x /home/user/.aria2/hook-complete.sh >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating aria2 hook-error file... "
    if [ -f /home/user/.aria2/hook-error.sh ]; then
      showoff
      print_already
      proceed=true
    else
      printf "#!/bin/sh\ncurl -X POST --data-urlencode \"payload={\\\"channel\\\": \\\"#general\\\", \\\"username\\\": \\\"aria2\\\", \\\"text\\\": \\\"Download error: \$3\\\", \\\"icon_emoji\\\": \\\":slack:\\\"}\" https://hooks.slack.com/services/%s\n" "$SLACK_WEBHOOK_KEY" 2>/dev/null | sudo -u user tee /home/user/.aria2/hook-error.sh >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting executable permissions hook-error file... "
    if [ "$(find /home/user/.aria2/hook-error.sh -perm -u=x 2>/dev/null)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      chmod +x /home/user/.aria2/hook-error.sh >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating aria2 download directory... "
    if [ -d /mnt/usb1/aria2 ]; then
      showoff
      print_already
      proceed=true
    else
      sudo -u user mkdir /mnt/usb1/aria2 >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Disabling un-needed autostart of aria2 service... "
    # shellcheck disable=SC2010
    if [ "$(ls -l /etc/rc.d | grep -F "../init.d/aria2")" = "" ]; then
      showoff
      print_already
      proceed=true
    else
      /etc/init.d/aria2 disable >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Starting up aria2 daemon... "
    if [ "$(pgrep -f "aria2c --conf-path=/home/user/.aria2/aria2.conf" 2>/dev/null)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      sudo -u user aria2c --conf-path=/home/user/.aria2/aria2.conf >/dev/null 2>&1
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    printf "   \e[34m•\e[0m Setting up aria2 daemon startup config... "
    if [ "$(grep -F "sudo -u user aria2c --conf-path=/home/user/.aria2/aria2.conf" /etc/rc.local 2>/dev/null)" != "" ]; then
      showoff
      print_already
      ARIA2_OK=true
    else
      sed -i -e '$i \sudo -u user aria2c --conf-path=/home/user/.aria2/aria2.conf &\n' /etc/rc.local >/dev/null 2>&1
      assert_status && ARIA2_OK=true
    fi
  fi
}


setup_aria2_scheduling() {
  printf " \e[34m•\e[0m Setup Aria2 Scheduling:\n"
  if [ $ARIA2_OK = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Starting up cron service... "
    if [ "$(pgrep -f "crond" 2>/dev/null)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      /etc/init.d/cron start >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi

    if [ $proceed = true ]; then
      proceed=false
      printf "   \e[34m•\e[0m Enabling autostart of cron service... "
      # shellcheck disable=SC2010
      if [ "$(ls -l /etc/rc.d | grep -F "../init.d/cron")" != "" ]; then
        showoff
        print_already
        proceed=true
      else
        /etc/init.d/cron enable >/dev/null 2>&1
        showoff
        assert_status && proceed=true
      fi
    fi

    if [ $proceed = true ]; then
      printf "   \e[34m•\e[0m Adding aria2 scheduling tasks to crontab... "
      if [ "$(crontab -l 2>/dev/null | grep -F "curl http://127.0.0.1:6800/jsonrpc" 2>/dev/null)" != "" ]; then
        showoff
        print_already
      else
        crontab -l > crontab.txt 2>/dev/null
        status_list=$?
        echo "0 1 * * * curl http://127.0.0.1:6800/jsonrpc -H \"Content-Type: application/json\" -H \"Accept: application/json\" --data '{\"jsonrpc\": \"2.0\",\"id\":1, \"method\": \"aria2.changeGlobalOption\", \"params\":[\"token:$ARIA2_RPC_TOKEN\",{\"max-overall-download-limit\":\"0\"}]}'" >> crontab.txt
        status_one=$?
        echo "0 8 * * * curl http://127.0.0.1:6800/jsonrpc -H \"Content-Type: application/json\" -H \"Accept: application/json\" --data '{\"jsonrpc\": \"2.0\",\"id\":1, \"method\": \"aria2.changeGlobalOption\", \"params\":[\"token:$ARIA2_RPC_TOKEN\",{\"max-overall-download-limit\":\"20K\"}]}'" >> crontab.txt
        status_two=$?
        echo "0 0 1 * * curl http://127.0.0.1:6800/jsonrpc -H \"Content-Type: application/json\" -H \"Accept: application/json\" --data '{\"jsonrpc\": \"2.0\",\"id\":1, \"method\": \"aria2.pauseAll\", \"params\":[\"token:$ARIA2_RPC_TOKEN\"]}'" >> crontab.txt
        status_three=$?
        crontab crontab.txt >/dev/null 2>&1
        status_install=$?
        rm crontab.txt >/dev/null 2>&1
        status_delete=$?
        if [ $status_list != 0 ] \
        || [ $status_one != 0 ] \
        || [ $status_two != 0 ] \
        || [ $status_three != 0 ] \
        || [ $status_install != 0 ] \
        || [ $status_delete != 0 ]; then
          wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
        else
          echo "" >/dev/null 2>&1 # imitating return code zero
        fi
        showoff
        assert_status
      fi
    fi
  else
    printf "   \e[34m•\e[0m Setting up aria2 scheduling service... "
    showoff
    printf "\e[33maria2 not setup!\e[0m\n"
  fi
}


setup_extroot() {
  printf " \e[34m•\e[0m Setup Extroot:\n"
  proceed=false
  printf "   \e[34m•\e[0m Checking if USB is mounted... "
  if [ "$(mount | grep -F "/mnt/usb1")" = "" ]; then
    wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
    showoff
    assert_status
  else
    showoff
    print_already
    proceed=true
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Copying /overlay to USB... "
    if [ -d /mnt/usb1/upper ] || [ -d /mnt/usb1/work ] || [ -d /mnt/usb1/etc ]; then
      showoff
      print_already
      proceed=true
    else
      tar -C /overlay/ -c . -f - | tar -C /mnt/usb1/ -xf - 2>/dev/null &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    printf "   \e[34m•\e[0m Setting up USB to be mounted at /overlay... "
    if [ "$(grep -F "option target '/mnt/usb1'" /etc/config/fstab)" != "" ]; then
      showoff
      print_already
    else
      printf "\nconfig mount\n\toption enabled '1'\n\toption device '/dev/sda1'\n\toption target '/overlay'\n\toption fstype 'ext4'\n\toption options 'async,noatime,rw'\n" >> /etc/config/fstab
      showoff
      assert_status
      REBOOT_REQUIRED=true
    fi
  fi
}


install_htop() {
  printf " \e[34m•\e[0m Install Htop:\n"
  printf "   \e[34m•\e[0m Installing htop... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F "htop")" != "" ]; then
    showoff
    print_already
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install htop >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


install_screen() {
  printf " \e[34m•\e[0m Install Screen:\n"
  printf "   \e[34m•\e[0m Installing screen... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F "screen")" != "" ]; then
    showoff
    print_already
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install screen >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_thingspeak_ping() {
  printf " \e[34m•\e[0m Setup ThingSpeak Ping:\n"
  proceed=false
  printf "   \e[34m•\e[0m Installing curl... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F "curl")" != "" ]; then
    showoff
    print_already
    proceed=true
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install curl >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status && proceed=true
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Starting up cron service... "
    if [ "$(pgrep -f "crond" 2>/dev/null)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      /etc/init.d/cron start >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Enabling autostart of cron service... "
    # shellcheck disable=SC2010
    if [ "$(ls -l /etc/rc.d | grep -F "../init.d/cron")" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      /etc/init.d/cron enable >/dev/null 2>&1
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Adding thingspeak ping task to crontab... "
    if [ "$(crontab -l | grep -F "curl \"https://api.thingspeak.com/update" 2>/dev/null)" != "" ]; then
      showoff
      print_already
    else
      crontab -l > crontab.txt 2>/dev/null
      status_list=$?
      echo "* * * * * curl \"https://api.thingspeak.com/update?api_key=$THINGSPEAK_API_KEY&field1=\$(awk '/MemFree/ {print \$2}' /proc/meminfo)\"" >> crontab.txt
      status_one=$?
      crontab crontab.txt >/dev/null 2>&1
      status_install=$?
      rm crontab.txt >/dev/null 2>&1
      status_delete=$?
      if [ $status_list != 0 ] \
      || [ $status_one != 0 ] \
      || [ $status_install != 0 ] \
      || [ $status_delete != 0 ]; then
        wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
      else
        echo "" >/dev/null 2>&1 # imitating return code zero
      fi
      showoff
      assert_status
    fi
  fi
}


setup_bash_default() {
  printf " \e[34m•\e[0m Install and Setup Bash as Default Shell:\n"
  proceed=false
  printf "   \e[34m•\e[0m Installing bash... "
  if [ "$(opkg list-installed 2>/dev/null | grep -F "bash")" != "" ]; then
    showoff
    print_already
    proceed=true
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install bash >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status && proceed=true
  fi

  if [ $proceed = true ]; then
    printf "   \e[34m•\e[0m Setting bash as default shell for future sessions... "
    if [ "$(sed -n '1p' /etc/passwd 2>/dev/null)" != "root:x:0:0:root:/root:/bin/ash" ]; then
      showoff
      print_already
    else
      showoff
      sed -i '1 c root:x:0:0:root:/root:/bin/bash' /etc/passwd >/dev/null 2>&1
      assert_status
      REBOOT_REQUIRED=true
    fi
  fi
}


setup_hostname() {
  printf " \e[34m•\e[0m Change Hostname:\n"
  printf "   \e[34m•\e[0m Changing hostname... "
  if [ "$(uci get system.@system[0].hostname 2>/dev/null)" = "nas1" ]; then
    showoff
    print_already
  else
    uci set system.@system[0].hostname='nas1' > /dev/null 2>&1
    status_set=$?
    uci commit > /dev/null 2>&1
    status_commit=$?
    /etc/init.d/system reload 2>&1
    status_reload=$?
    if [ $status_set != 0 ] \
    || [ $status_commit != 0 ] \
    || [ $status_reload != 0 ]; then
      wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
    else
      echo "" >/dev/null 2>&1 # imitating return code zero
    fi
    showoff
    assert_status
  fi
}


setup_timezone() {
  printf " \e[34m•\e[0m Change Timezone:\n"
  printf "   \e[34m•\e[0m Changing timezone... "
  if [ "$(uci get system.@system[0].timezone 2>/dev/null)" = "PKT-5" ]; then
    showoff
    print_already
  else
    uci set system.@system[0].timezone='PKT-5' > /dev/null 2>&1
    status_set_one=$?
    uci set system.@system[0].zonename='Asia/Karachi' > /dev/null 2>&1
    status_set_two=$?
    uci commit > /dev/null 2>&1
    status_commit=$?
    /etc/init.d/system reload 2>&1
    status_reload=$?
    if [ $status_set_one != 0 ] \
    || [ $status_set_two != 0 ] \
    || [ $status_commit != 0 ] \
    || [ $status_reload != 0 ]; then
      wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
    else
      echo "" >/dev/null 2>&1 # imitating return code zero
    fi
    showoff
    assert_status
  fi
}


setup_external_git() {
  printf " \e[34m•\e[0m Setup External Git:\n"
  git_download_required=true
  proceed=false
  printf "   \e[34m•\e[0m Checking if USB is mounted... "
  if [ "$(mount | grep -F "/mnt/usb1")" = "" ]; then
    wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
    showoff
    assert_status
  else
    showoff
    print_already
    proceed=true
  fi

  if [ $proceed = true ]; then
    printf "   \e[34m•\e[0m Checking if updating / installing git is required... "
    repo_git_v="$(opkg info git 2>/dev/null | awk '/Version/ {print $2}' | cut -d - -f 1)"
    if [ "$repo_git_v" != "" ] && 
       [ "$repo_git_v" != "$(git --version 2>/dev/null | awk '{print $3}')" ]; then
      print_required
      printf "   \e[34m•\e[0m Removing old version of git... "
      rm -rf /mnt/usb1/.data/git 2>/dev/null &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status && proceed=true
      git_download_required=true
    else
      print_not_required
    fi
  fi

  if [ $proceed = true ]; then
    if [ -d /mnt/usb1/.data/git/usr ]; then
      git_download_required=false
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating directory for git... "
    if [ -d /mnt/usb1/.data/git ]; then
      showoff
      print_already
      proceed=true
    else
      mkdir -p "/mnt/usb1/.data/git" 2>/dev/null
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Detecting OpenWrt version... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      openwrt_version="$(awk -F\' '/DISTRIB_RELEASE/ {print $2}' /etc/openwrt_release 2>/dev/null)"
      if [ "$openwrt_version" = "" ]; then
        wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
      else
        echo "" >/dev/null 2>&1 # imitating return code zero
      fi
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Detecting system architecture... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      openwrt_arch="$(awk -F\' '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release 2>/dev/null)"
      if [ "$openwrt_arch" = "" ]; then
        wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
      else
        echo "" >/dev/null 2>&1 # imitating return code zero
      fi
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Detecting git version... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      git_version="$(opkg info git 2>/dev/null | awk '/Version/ {print $2}')"
      if [ "$git_version" = "" ]; then
        wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
      else
        echo "" >/dev/null 2>&1 # imitating return code zero
      fi
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Detecting git-http version... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      git_http_version="$(opkg info git 2>/dev/null | awk '/Version/ {print $2}')"
      if [ "$git_http_version" = "" ]; then
        wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
      else
        echo "" >/dev/null 2>&1 # imitating return code zero
      fi
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Downloading git... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      url="http://downloads.openwrt.org/releases/$openwrt_version/packages/$openwrt_arch/packages/git_${git_version}_$openwrt_arch.ipk"
      wget -q -O "/mnt/usb1/.data/git/git_${git_version}_$openwrt_arch.ipk" "$url" 2>/dev/null &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Downloading git-http... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      url="http://downloads.openwrt.org/releases/$openwrt_version/packages/$openwrt_arch/packages/git-http_${git_http_version}_$openwrt_arch.ipk"
      wget -q -O "/mnt/usb1/.data/git/git-http_${git_http_version}_$openwrt_arch.ipk" "$url" 2>/dev/null &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Extracting git ipk file... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      tar -C /mnt/usb1/.data/git -zxf "/mnt/usb1/.data/git/git_${git_version}_$openwrt_arch.ipk" ./data.tar.gz 2>/dev/null &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Extracting data... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      tar -C /mnt/usb1/.data/git -zxf /mnt/usb1/.data/git/data.tar.gz 2>/dev/null &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Cleaning up... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      rm "/mnt/usb1/.data/git/git_${git_version}_$openwrt_arch.ipk" /mnt/usb1/.data/git/data.tar.gz 2>/dev/null
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Extracting git-http ipk file... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      tar -C /mnt/usb1/.data/git -zxf "/mnt/usb1/.data/git/git-http_${git_http_version}_$openwrt_arch.ipk" ./data.tar.gz 2>/dev/null &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Extracting data... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      tar -C /mnt/usb1/.data/git -zxf /mnt/usb1/.data/git/data.tar.gz 2>/dev/null &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Cleaning up... "
    if [ $git_download_required = false ]; then
      showoff
      print_not_required
      proceed=true
    else
      rm "/mnt/usb1/.data/git/git-http_${git_http_version}_$openwrt_arch.ipk" /mnt/usb1/.data/git/data.tar.gz 2>/dev/null
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = false ]; then
    printf "   \e[34m•\e[0m Cleaning up incomplete git files... "
    rm -rf /mnt/usb1/.data/git 2>/dev/null &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting up external git for future sessions... "
    if [ "$(grep -F "/mnt/usb1/.data/git/usr/bin" /etc/profile)" != "" ]; then
      showoff
      print_already
      proceed=true
    else
      printf "export PATH=/mnt/usb1/.data/git/usr/lib/git-core:/mnt/usb1/.data/git/usr/bin:\$PATH" >> /etc/profile
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Setting up external git for current session... "
    if [ "$(echo "$PATH" | grep -F "/mnt/usb1/.data/git/usr/bin")" != "" ]; then
      showoff
      print_already
      proceed=true
      GIT_OK=true
    else
      showoff
      printf "\e[33mNot supported! Please set manually by entering \"export PATH=/mnt/usb1/.data/git/usr/lib/git-core:/mnt/usb1/.data/git/usr/bin:\$PATH\" in the terminal!\e[0m\n"
      proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Creating git templates directory... "
    if [ -d "/usr/share/git-core/templates" ]; then
      showoff
      print_already
      proceed=true
    else
      mkdir -p /usr/share/git-core/templates 2>/dev/null
      showoff
      assert_status && proceed=true
    fi
  fi

  if [ $proceed = true ]; then
    proceed=false
    printf "   \e[34m•\e[0m Adding git user.name... "
    if [ $GIT_OK = true ]; then
      if [ "$(git config --global user.name 2>/dev/null)" != "" ]; then
        showoff
        print_already
        proceed=true
      else
        git config --global user.name "Ameer Dawood" 2>/dev/null
        showoff
        assert_status && proceed=true
      fi
    else
      printf "\e[33mgit not setup!\e[0m\n"
    fi
  fi

  if [ $proceed = true ]; then
    printf "   \e[34m•\e[0m Adding git user.email... "
    if [ $GIT_OK = true ]; then
      if [ "$(git config --global user.email 2>/dev/null)" != "" ]; then
        showoff
        print_already
      else
        git config --global user.email "ameer1234567890@gmail.com" 2>/dev/null
        showoff
        assert_status
      fi
    else
      printf "\e[33mgit not setup!\e[0m\n"
    fi
  fi
}


setup_aria2_webui() {
  printf " \e[34m•\e[0m Install and Setup Aria2 Webui:\n"
  proceed=false
  if [ $ARIA2_OK = true ]; then
    printf "   \e[34m•\e[0m Installing aria2 webui... "
    if [ -d /mnt/usb1/.data/webui-aria2 ]; then
      showoff
      print_already
      proceed=true
    else
      if [ $GIT_OK = true ]; then
        git clone --quiet --depth=1 https://github.com/ziahamza/webui-aria2 /mnt/usb1/.data/webui-aria2 2>/dev/null &
        bg_pid=$!
        show_progress $bg_pid
        wait $bg_pid
        assert_status && proceed=true
      else
        printf "\e[33mgit not setup!\e[0m\n"
      fi
    fi

    if [ $proceed = true ]; then
      printf "   \e[34m•\e[0m Setting up aria2 webui... "
      if [ -d /www/webui-aria2 ]; then
        showoff
        print_already
      else
        ln -s /mnt/usb1/.data/webui-aria2/docs /www/webui-aria2 >/dev/null 2>&1
        showoff
        assert_status
      fi
    fi
  fi
}


#### tasks to run. comment out any tasks that are not required.
notify_on_startup
install_openssh_sftp_server
set_nano_default
setup_usb_storage
setup_samba
make_samba_wan_accessible
setup_rsync
disable_dropbear_password_auth
setup_remote_ssh
setup_router_remote_http
setup_aria2
setup_aria2_scheduling
install_htop
install_screen
setup_thingspeak_ping
setup_bash_default
setup_hostname
setup_timezone
setup_external_git
setup_aria2_webui
# setup_extroot # preferrably, this should be done last


if [ $REBOOT_REQUIRED = true ]; then
  printf "\n\e[33mReboot required! Do you want to reboot now? (Y/N) \e[0m\n"
  read -r opt
  if [ "$opt" = "Y" ] || [ "$opt" = "y" ] || [ "$opt" = "yes" ] || [ "$opt" = "YES" ] || [ "$opt" = "Yes" ]; then
    echo "Rebooting now..."
    showoff
    reboot
  fi
fi


echo "" # just an empty line before we end
