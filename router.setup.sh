#!/bin/sh

REBOOT_REQUIRED=false

clear
echo ""
echo " ##############################################################################"
echo " ##                                                                          ##"
echo " ##                               ROUTER SETUP                               ##"
echo " ##                                                                          ##"
echo " ##                              by Ameer Dawood                             ##"
echo " ##                                                                          ##"
echo " ##         This script runs my customized setup process on OpenWRT          ##"
echo " ##                                                                          ##"
echo " ##############################################################################"
echo ""


kill_tools() {
  tools="opkg tar"
  printf "\n\n User cancelled!\n"
  for tool in $tools; do
    if [ "$(pidof "$tool")" != "" ]; then
      printf " Killing %s... " "$tool"
    	killall "$tool" >/dev/null 2>&1
      status="$?"
      if [ "$status" = 0 ]; then
        printf "\e[32mDone!\e[0m\n"
      else
        printf "\e[91mFailed!\e[0m\n"
      fi
    fi
  done
  echo ""
  exit 0
}


trap kill_tools 1 2 3 15


help() {
  echo ""
  echo "Usage: $0 [-k KEY] [-t TOKEN]"
  echo ""
  echo "Run my customized setup process on OpenWRT"
  echo ""
  printf "\t-k KEY\t\tIFTTT webhook key\n"
  printf "\t-t TOKEN\tRPC token to be used in aria2\n"
  printf "\t-h\t\tshow help message and exit\n"
  echo ""
  exit
}


while getopts "k:t:h" opt; do
  case "$opt" in
    k ) IFTTT_KEY="$OPTARG" ;;
    t ) ARIA2_RPC_TOKEN="$OPTARG" ;;
    h ) help ;;
    ? ) help ;;
  esac
done


if [ -z "$IFTTT_KEY" ] || [ -z "$ARIA2_RPC_TOKEN" ]; then
  echo "Some or all of the parameters are empty";
  help
fi

assert_status() {
  status="$?"
  if [ "$status" = 0 ]; then
    printf "\e[32mDone!\e[0m\n"
  else
    printf "\e[91mFailed!\e[0m\n"
  fi
}


print_already() {
  printf "\e[36mAlready Done!\e[0m\n"
}


print_opkg_busy() {
  printf "\e[91mopkg Busy!\e[0m\n"
}


print_not_required() {
  printf "\e[36mNot Required!\e[0m\n"
}


showoff() {
  # this is just a showoff to the user that some processing is happening in the background.
  # I do this since busybox's sleep does not support frctional seconds and 1 second is too long.

  # here we collect return code for last command, prior to calling showoff, which most probably
  # is the important command that we ran
  status="$?" 
  i=0;
  while [ $i -le 300 ]; do
    echo "" >/dev/null
    i=$(( i + 1 ))
  done
  # here we return the return code collected from the last command, prior to
  # calling showoff, so that the next command in the chain (most probably assert_status) gets
  # its required return code
  return "$status" 
}


show_progress() {
  bg_pid="$1"
  progress_state=0
  printf "  ⠋\b\b\b"
  while [ "$(ps | awk '{print $1}' | grep "$bg_pid")" != "" ]; do
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
    progress_state=$((progress_state + 1))
    if [ $progress_state -gt 8 ]; then
      progress_state=0
    fi
    showoff
  done
}


update_opkg() {
  printf " \e[34m•\e[0m Running opkg update... "
  if [ "$(ls /var/opkg-lists/ 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    opkg update >/dev/null 2>&1 &
    bg_pid="$!"
    show_progress "$bg_pid"
    wait "$bg_pid"
    assert_status
  fi
}


# check if opkg update is required, and perform update if required
printf " \e[34m•\e[0m Checking if opkg update is required... "
opkg find zsh > opkgstatus.txt 2>/dev/null & # replace zsh with any tool that is definitely not installed
bg_pid="$!"
show_progress "$bg_pid"
wait "$bg_pid"
status="$?"
if [ "$status" = 0 ]; then
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
  printf " \e[34m•\e[0m Setting up notification via IFTTT, on router startup... "
  if [ "$(grep "sleep 14 && wget -O - http://maker.ifttt.com/trigger/router-reboot/with/key/" /etc/rc.local 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    sed -i -e '$i \sleep 14 && wget -O - http://maker.ifttt.com/trigger/router-reboot/with/key/'"$IFTTT_KEY"' &\n' /etc/rc.local >/dev/null 2>&1
    showoff
    assert_status
  fi
}


install_openssh_sftp_server() {
  printf " \e[34m•\e[0m Installing OpenSSH SFTP server... "
  if [ "$(opkg list-installed 2>/dev/null | grep openssh-sftp-server)" != "" ]; then
    showoff
    print_already
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install openssh-sftp-server >/dev/null 2>&1 &
    bg_pid="$!"
    show_progress "$bg_pid"
    wait "$bg_pid"
    assert_status
  fi
}


set_nano_default() {
  printf " \e[34m•\e[0m Installing nano... "
  if [ "$(opkg list-installed 2>/dev/null | grep nano)" != "" ]; then
    showoff
    print_already
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install nano >/dev/null 2>&1 &
    bg_pid="$!"
    show_progress "$bg_pid"
    wait "$bg_pid"
    assert_status
  fi

  printf " \e[34m•\e[0m Setting nano as default editor for future sessions... "
  if [ "$(grep "export EDITOR=nano" /etc/profile 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    showoff
    sed -i '$ a \\nexport EDITOR=nano\n' /etc/profile >/dev/null 2>&1
    assert_status
  fi

  printf " \e[34m•\e[0m Setting nano as default editor for current session... "
  if [ "$(grep "export EDITOR=nano" /etc/profile 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    showoff
    export EDITOR=nano >/dev/null 2>&1
    assert_status
  fi
}


setup_usb_storage() {
  packages="kmod-usb-core usbutils kmod-usb-storage kmod-fs-ext4 block-mount"
  for package in $packages; do
    printf " \e[34m•\e[0m Installing required packages for USB storage (%s)... " "$package"
    if [ "$(opkg list-installed 2>/dev/null | grep "$package")" != "" ]; then
      showoff
      print_already
    elif [ -f /var/lock/opkg.lock ]; then
      showoff
      print_opkg_busy
    else
      opkg install "$package" >/dev/null 2>&1 &
      bg_pid="$!"
      show_progress "$bg_pid"
      wait "$bg_pid"
      assert_status
    fi
  done

  printf " \e[34m•\e[0m Creating mount directory... "
  if [ -d /mnt/usb1 ]; then
    showoff
    print_already
  else
    showoff
    mkdir /mnt/usb1 >/dev/null 2>&1
    assert_status
  fi

  printf " \e[34m•\e[0m Touching empty file identifying mount status... "
  if [ -f /mnt/usb1/USB_NOT_MOUNTED ] || [ "$(mount | grep "/mnt/usb1")" != "" ]; then
    showoff
    print_already
  else
    showoff
    touch /mnt/usb1/USB_NOT_MOUNTED >/dev/null 2>&1
    assert_status
  fi

  printf " \e[34m•\e[0m Test mounting in current session... "
  if [ -f /mnt/usb1/USB_NOT_MOUNTED ] || [ "$(mount | grep "/mnt/usb1")" != "" ]; then
    showoff
    print_already
  else
    mount -t ext4 -o rw,async,noatime /dev/sda1 /mnt/usb1 >/dev/null 2>&1
    assert_status
  fi

  printf " \e[34m•\e[0m Setting up persistent mount config... "
  if [ "$(grep "/mnt/usb1" /etc/config/fstab)" != "" ]; then
    showoff
    print_already
  else
    sed -i '$ a \\nconfig mount\n\toption enabled '"'1'"'\n\toption device '"'/dev/sda1'"'\n\toption target '"'/mnt/usb1'"'\n\toption fstype '"'ext4'"'\n\toption options '"'async,noatime,rw'"'\n' /etc/config/fstab >/dev/null 2>&1
    assert_status
  fi
}


setup_samba() {
  samba_restart_required=false
  packages="samba36-server luci-app-samba"
  for package in $packages; do
    printf " \e[34m•\e[0m Installing required packages for samba (%s)... " "$package"
    if [ "$(opkg list-installed 2>/dev/null | grep "$package")" != "" ]; then
      showoff
      print_already
    elif [ -f /var/lock/opkg.lock ]; then
      showoff
      print_opkg_busy
    else
      opkg install "$package" >/dev/null 2>&1 &
      bg_pid="$!"
      show_progress "$bg_pid"
      wait "$bg_pid"
      assert_status
    fi
  done

  printf " \e[34m•\e[0m Setting up samba config... "
  if [ "$(grep "option 'path' '/mnt/usb1'" /etc/config/samba)" != "" ]; then
    showoff
    print_already
  else
    printf "config samba\n\toption workgroup 'WORKGROUP'\n\toption homes '1'\n\toption name 'miwifimini'\n\toption description 'miwifimini'\n\nconfig 'sambashare'\n\toption 'name' 'usb1'\n\toption 'path' '/mnt/usb1'\n\toption 'users' 'user'\n\toption 'guest_ok' 'yes'\n\toption 'create_mask' '0644'\n\toption 'dir_mask' '0777'\n\toption 'read_only' 'no'\n" > /etc/config/samba 2>/dev/null
    showoff
    assert_status
    samba_restart_required=true
  fi

  printf " \e[34m•\e[0m Setting up smb.conf.template... "
  if [ "$(grep "min protocol = SMB2" /etc/samba/smb.conf.template)" != "" ]; then
    showoff
    print_already
  else
    sed -i '$ a \\n\tmin protocol = SMB2\n' /etc/samba/smb.conf.template >/dev/null 2>&1
    showoff
    assert_status
    samba_restart_required=true
  fi

  printf " \e[34m•\e[0m Setting up samba system user... "
  if [ "$(grep "user:" /etc/passwd)" != "" ]; then
    showoff
    print_already
  else
    sed -i '$ a \\nuser:x:501:501:user:/home/user:/bin/ash\n' /etc/passwd >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Setting up password for samba system user... "
  if [ "$(grep "user:x:" /etc/passwd)" = "" ]; then
    showoff
    print_already
  else
    showoff
    printf "\e[33mNot supported! Please set a password manually by entering \"passwd user\" in the terminal! \e[0m"
  fi

  printf " \e[34m•\e[0m Setting up user & password for smb user... "
  if [ "$(grep "user:501:" /etc/samba/smbpasswd)" != "" ]; then
    showoff
    print_already
  else
    showoff
    printf "\e[33mNot supported! Please set a password manually by entering \"smbpasswd -a user\" in the terminal! \e[0m"
  fi

  printf " \e[34m•\e[0m Restarting samba... "
  if [ $samba_restart_required = true ]; then
    /etc/init.d/samba restart >/dev/null 2>&1 &
    bg_pid="$!"
    show_progress "$bg_pid"
    wait "$bg_pid"
    assert_status
  else
    print_not_required
  fi
}


make_samba_wan_accessible() {
  samba_restart_required=false
  printf " \e[34m•\e[0m Making samba accessible from WAN... "
  if [ "$(grep "bind interfaces only = no" /etc/samba/smb.conf.template)" != "" ]; then
    showoff
    print_already
  else
    sed -i '/\tbind interfaces only = yes/ c\ \tbind interfaces only = no' /etc/samba/smb.conf.template >/dev/null 2>&1
    showoff
    assert_status
    samba_restart_required=true
  fi

  printf " \e[34m•\e[0m Restarting samba... "
  if [ $samba_restart_required = true ]; then
    /etc/init.d/samba restart >/dev/null 2>&1 &
    bg_pid="$!"
    show_progress "$bg_pid"
    wait "$bg_pid"
    assert_status
  else
    print_not_required
  fi
}


setup_rsync() {
  printf " \e[34m•\e[0m Installing rsync... "
  if [ "$(opkg list-installed 2>/dev/null | grep rsync)" != "" ]; then
    showoff
    print_already
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install rsync >/dev/null 2>&1 &
    bg_pid="$!"
    show_progress "$bg_pid"
    wait "$bg_pid"
    assert_status
  fi

  printf " \e[34m•\e[0m Configuring rsync... "
  if [ "$(grep "path = /mnt/usb1" /etc/rsyncd.conf 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    printf 'pid file = /var/run/rsyncd.pid\nlog file = /var/log/rsyncd.log\nlock file = /var/run/rsync.lock\nuse chroot = no\nuid = user\ngid = 501\nread only = no\n\n[usb1]\npath = /mnt/usb1\ncomment = NAS of Ameer\nlist = yes\nhosts allow = 192.168.100.1/24' > /etc/rsyncd.conf 2>/dev/null
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Starting up rsync daemon... "
  if [ "$(pgrep -f "rsync --daemon" 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    rsync --daemon >/dev/null 2>&1
    assert_status
  fi

  printf " \e[34m•\e[0m Setting up rsync daemon startup config... "
  if [ "$(grep "rsync --daemon" /etc/rc.local 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    sed -i -e '$i \rsync --daemon &\n' /etc/rc.local >/dev/null 2>&1
    assert_status
  fi
}


disable_dropbear_password_auth() {
  dropbear_restart_required=false
  printf " \e[34m•\e[0m Disabling password authentication in dropbear... "
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

  printf " \e[34m•\e[0m Restarting dropbear... "
  if [ $dropbear_restart_required = true ]; then
    /etc/init.d/dropbear restart >/dev/null 2>&1 &
    bg_pid="$!"
    show_progress "$bg_pid"
    wait "$bg_pid"
    assert_status
  else
    print_not_required
  fi
}


setup_remote_ssh() {
  printf " \e[34m•\e[0m Installing autossh... "
  if [ "$(opkg list-installed 2>/dev/null | grep autossh)" != "" ]; then
    showoff
    print_already
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install autossh >/dev/null 2>&1 &
    bg_pid="$!"
    show_progress "$bg_pid"
    wait "$bg_pid"
    assert_status
  fi

  printf " \e[34m•\e[0m Creating serveo service... "
  if [ -f /etc/init.d/serveo ]; then
    showoff
    print_already
  else
    printf "#!/bin/sh /etc/rc.common\n\nSTART=99\n\nstart() {\n\techo \"Starting serveo service...\"\n\t/usr/sbin/autossh -M 22 -y -R ameer:22:localhost:22 serveo.net < /dev/ptmx &\n}\n\nstop() {\n\techo \"Stopping serveo service...\"\n\tpids=\"\$(pgrep -f ameer)\"\n\tfor pid in \$pids; do\n\t\t/bin/kill \"\$pid\"\n\tdone\n}\n\nrestart() {\n\tstop\n\tstart\n}\n" > /etc/init.d/serveo 2>/dev/null
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Setting executable permissions serveo service... "
  if [ "$(find /etc/init.d/serveo -perm -u=x 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    chmod +x /etc/init.d/serveo >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Starting serveo service... "
  if [ "$(pgrep -f "ameer")" != "" ]; then
    showoff
    print_already
  else
    /etc/init.d/serveo start >/dev/null 2>&1 &
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Enabling autostart of serveo service... "
  # shellcheck disable=SC2010
  if [ "$(ls -l /etc/rc.d | grep ../init.d/serveo)" != "" ]; then
    showoff
    print_already
  else
    /etc/init.d/serveo enable >/dev/null 2>&1
    showoff
    assert_status
  fi
}


setup_aria2() {
  packages="aria2 sudo"
  for package in $packages; do
    printf " \e[34m•\e[0m Installing required packages for aria2 (%s)... " "$package"
    if [ "$(opkg list-installed 2>/dev/null | grep "$package")" != "" ]; then
      showoff
      print_already
    elif [ -f /var/lock/opkg.lock ]; then
      showoff
      print_opkg_busy
    else
      opkg install "$package" >/dev/null 2>&1 &
      bg_pid="$!"
      show_progress "$bg_pid"
      wait "$bg_pid"
      assert_status
    fi
  done

  printf " \e[34m•\e[0m Creating home directory for user... "
  if [ -d /home/user ]; then
    showoff
    print_already
  else
    mkdir -p /home/user >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Assigning ownership of user's home directory to user... "
  if [ "$(find /home/user -maxdepth 0 -user user)" != "" ]; then
    showoff
    print_already
  else
    chown user.501 /home/user >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Creating .aria2 directory... "
  if [ -d /home/user/.aria2 ]; then
    showoff
    print_already
  else
    sudo -u user mkdir /home/user/.aria2 >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Creating aria2 session file... "
  if [ -f /home/user/.aria2/session ]; then
    showoff
    print_already
  else
    sudo -u user touch /home/user/.aria2/session >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Creating aria2 configuration file... "
  if [ -f /home/user/.aria2/aria2.conf ]; then
    showoff
    print_already
  else
    printf "daemon=true\ndir=/mnt/usb1/aria2\nfile-allocation=prealloc\ncontinue=true\nsave-session=/home/user/.aria2/session\ninput-file=/home/user/.aria2/session\nsave-session-interval=10\nforce-save=true\nmax-connection-per-server=10\nenable-rpc=true\nrpc-listen-all=true\nrpc-secret=%s\nrpc-listen-port=6800\nrpc-allow-origin-all=true\non-download-complete=/home/user/.aria2/hook-complete.sh\non-bt-download-complete=/home/user/.aria2/hook-complete.sh\non-download-error=/home/user/.aria2/hook-error.sh\nmax-overall-download-limit=40K\n" "$ARIA2_RPC_TOKEN" 2>/dev/null | sudo -u user tee /home/user/.aria2/aria2.conf >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Creating aria2 hook-complete file... "
  if [ -f /home/user/.aria2/hook-complete.sh ]; then
    showoff
    print_already
  else
    printf "#!/bin/sh\ncurl -X POST -H \"Content-Type: application/json\" -d '{\"value1\":\"'\$3'\"}' https://maker.ifttt.com/trigger/aria2_complete/with/key/%s\n" "$IFTTT_KEY" 2>/dev/null | sudo -u user tee /home/user/.aria2/hook-complete.sh >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Setting executable permissions hook-complete file... "
  if [ "$(find /home/user/.aria2/hook-complete.sh -perm -u=x 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    chmod +x /home/user/.aria2/hook-complete.sh >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Creating aria2 hook-error file... "
  if [ -f /home/user/.aria2/hook-error.sh ]; then
    showoff
    print_already
  else
    printf "#!/bin/sh\ncurl -X POST -H \"Content-Type: application/json\" -d '{\"value1\":\"'\$3'\"}' https://maker.ifttt.com/trigger/aria2_error/with/key/%s\n" "$IFTTT_KEY" 2>/dev/null | sudo -u user tee /home/user/.aria2/hook-error.sh >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Setting executable permissions hook-error file... "
  if [ "$(find /home/user/.aria2/hook-error.sh -perm -u=x 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    chmod +x /home/user/.aria2/hook-error.sh >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Creating aria2 download directory... "
  if [ -d /mnt/usb1/aria2 ]; then
    showoff
    print_already
  else
    sudo -u user mkdir /mnt/usb1/aria2 >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Disabling un-needed autostart of aria2 service... "
  # shellcheck disable=SC2010
  if [ "$(ls -l /etc/rc.d | grep ../init.d/aria2)" = "" ]; then
    showoff
    print_already
  else
    /etc/init.d/aria2 disable >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Starting up aria2 daemon... "
  if [ "$(pgrep -f "aria2c --conf-path=/home/user/.aria2/aria2.conf" 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    sudo -u user aria2c --conf-path=/home/user/.aria2/aria2.conf >/dev/null 2>&1
    assert_status
  fi

  printf " \e[34m•\e[0m Setting up aria2 daemon startup config... "
  if [ "$(grep "sudo -u user aria2c --conf-path=/home/user/.aria2/aria2.conf" /etc/rc.local 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    sed -i -e '$i \sudo -u user aria2c --conf-path=/home/user/.aria2/aria2.conf &\n' /etc/rc.local >/dev/null 2>&1
    assert_status
  fi
}


setup_aria2_scheduling() {
  printf " \e[34m•\e[0m Starting up cron service... "
  if [ "$(pgrep -f "crond" 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    /etc/init.d/cron start >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Enabling autostart of cron service... "
  # shellcheck disable=SC2010
  if [ "$(ls -l /etc/rc.d | grep ../init.d/cron)" != "" ]; then
    showoff
    print_already
  else
    /etc/init.d/cron enable >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Adding aria2 scheduling tasks to crontab... "
  if [ "$(crontab -l | grep "curl http://127.0.0.1:6800/jsonrpc" 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    crontab -l > crontab.txt 2>/dev/null
    status_list="$?"
    echo "0 1 * * * curl http://127.0.0.1:6800/jsonrpc -H \"Content-Type: application/json\" -H \"Accept: application/json\" --data '{\"jsonrpc\": \"2.0\",\"id\":1, \"method\": \"aria2.changeGlobalOption\", \"params\":[\"token:$ARIA2_RPC_TOKEN\",{\"max-overall-download-limit\":\"0\"}]}'" >> crontab.txt
    status_one="$?"
    echo "0 8 * * * curl http://127.0.0.1:6800/jsonrpc -H \"Content-Type: application/json\" -H \"Accept: application/json\" --data '{\"jsonrpc\": \"2.0\",\"id\":1, \"method\": \"aria2.changeGlobalOption\", \"params\":[\"token:$ARIA2_RPC_TOKEN\",{\"max-overall-download-limit\":\"40K\"}]}'" >> crontab.txt
    status_two="$?"
    echo "0 0 1 * * curl http://127.0.0.1:6800/jsonrpc -H \"Content-Type: application/json\" -H \"Accept: application/json\" --data '{\"jsonrpc\": \"2.0\",\"id\":1, \"method\": \"aria2.pauseAll\", \"params\":[\"token:$ARIA2_RPC_TOKEN\"]}'" >> crontab.txt
    status_three="$?"
    crontab crontab.txt >/dev/null 2>&1
    status_install="$?"
    rm crontab.txt >/dev/null 2>&1
    status_delete="$?"
    if [ "$status_list" != 0 ] \
    || [ "$status_one" != 0 ] \
    || [ "$status_two" != 0 ] \
    || [ "$status_three" != 0 ] \
    || [ "$status_install" != 0 ] \
    || [ "$status_delete" != 0 ]; then
      wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
    else
      echo "" >/dev/null 2>&1 # imitating return code zero
    fi
    showoff
    assert_status
  fi
}


setup_extroot() {
  printf " \e[34m•\e[0m Checking if USB is mounted... "
  if [ "$(mount | grep "/mnt/usb1")" = "" ]; then
    wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
    showoff
    assert_status
  else
    showoff
    print_already
    printf " \e[34m•\e[0m Copying /overlay to USB... "
    if [ -d /mnt/usb1/upper ] || [ -d /mnt/usb1/work ] || [ -d /mnt/usb1/etc ]; then
      showoff
      print_already
    else
      tar -C /overlay/ -c . -f - | tar -C /mnt/usb1/ -xf - 2>/dev/null &
      bg_pid="$!"
      show_progress "$bg_pid"
      wait "$bg_pid"
      assert_status
    fi
    printf " \e[34m•\e[0m Setting up USB to be mounted at /overlay... "
    if [ "$(grep "option target '/mnt/usb1'" /etc/config/fstab)" != "" ]; then
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


setup_thingspeak_ping() {
  printf " \e[34m•\e[0m Starting up cron service... "
  if [ "$(pgrep -f "crond" 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    /etc/init.d/cron start >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Enabling autostart of cron service... "
  # shellcheck disable=SC2010
  if [ "$(ls -l /etc/rc.d | grep ../init.d/cron)" != "" ]; then
    showoff
    print_already
  else
    /etc/init.d/cron enable >/dev/null 2>&1
    showoff
    assert_status
  fi

  printf " \e[34m•\e[0m Adding thingspeak ping task to crontab... "
  if [ "$(crontab -l | grep "curl \"https://api.thingspeak.com/update" 2>/dev/null)" != "" ]; then
    showoff
    print_already
  else
    crontab -l > crontab.txt 2>/dev/null
    status_list="$?"
    echo "* * * * * curl \"https://api.thingspeak.com/update?api_key=9QY15FLFX4REDCQ5&field1=$(grep MemFree /proc/meminfo | awk '{print $2}')\"" >> crontab.txt
    status_one="$?"
    crontab crontab.txt >/dev/null 2>&1
    status_install="$?"
    rm crontab.txt >/dev/null 2>&1
    status_delete="$?"
    if [ "$status_list" != 0 ] \
    || [ "$status_one" != 0 ] \
    || [ "$status_install" != 0 ] \
    || [ "$status_delete" != 0 ]; then
      wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
    else
      echo "" >/dev/null 2>&1 # imitating return code zero
    fi
    showoff
    assert_status
  fi
}


setup_bash_default() {
  printf " \e[34m•\e[0m Installing bash... "
  if [ "$(opkg list-installed 2>/dev/null | grep bash)" != "" ]; then
    showoff
    print_already
  elif [ -f /var/lock/opkg.lock ]; then
    showoff
    print_opkg_busy
  else
    opkg install bash >/dev/null 2>&1 &
    bg_pid="$!"
    show_progress "$bg_pid"
    wait "$bg_pid"
    assert_status
  fi

  printf " \e[34m•\e[0m Setting bash as default shell for future sessions... "
  if [ "$(sed -n '1p' /etc/passwd 2>/dev/null)" != "root:x:0:0:root:/root:/bin/ash" ]; then
    showoff
    print_already
  else
    showoff
    sed -i '1 c root:x:0:0:root:/root:/bin/bash' /etc/passwd >/dev/null 2>&1
    assert_status
    REBOOT_REQUIRED=true
  fi
}


setup_hostname() {
  printf " \e[34m•\e[0m Changing hostname... "
  if [ "$(uci get system.@system[0].hostname 2>/dev/null)" = "miwifimini" ]; then
    showoff
    print_already
  else
    uci set system.@system[0].hostname='miwifimini' > /dev/null 2>&1
    status_set="$?"
    uci commit > /dev/null 2>&1
    status_commit="$?"
    if [ "$status_set" != 0 ] \
    || [ "$status_commit" != 0 ]; then
      wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
    else
      echo "" >/dev/null 2>&1 # imitating return code zero
    fi
    showoff
    assert_status
    REBOOT_REQUIRED=true
  fi
}


setup_timezone() {
  printf " \e[34m•\e[0m Changing timezone... "
  if [ "$(uci get system.@system[0].timezone 2>/dev/null)" = "<+05>-5" ]; then
    showoff
    print_already
  else
    uci set system.@system[0].timezone='<+05>-5' > /dev/null 2>&1
    status_set="$?"
    uci commit > /dev/null 2>&1
    status_commit="$?"
    if [ "$status_set" != 0 ] \
    || [ "$status_commit" != 0 ]; then
      wrong_cmd >/dev/null 2>&1 # imitating a non-zero return
    else
      echo "" >/dev/null 2>&1 # imitating return code zero
    fi
    showoff
    assert_status
    REBOOT_REQUIRED=true
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
setup_aria2
setup_aria2_scheduling
setup_thingspeak_ping
setup_bash_default
setup_hostname
setup_timezone
setup_extroot # preferrably, this should be done last


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


#TODO: Disable autossh service? Testing now...
