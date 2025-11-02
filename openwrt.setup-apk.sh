#!/bin/bash

#### Start of configurable variables
TIMEZONE='Asia/Karachi'
TIMEZONE_D='PKT-5'
WIFI_NAME='Mango'
declare -A backup_script
backup_script=( \
  ["usb11"]="backup.sh" \
)
backup_schedule=( \
  ["usb11"]="0 3 * * *" \
)
#### End of of configurable variables

#### .secrets.txt
# Create a file named .secrets.txt in the below format (without hashes)
# HOSTNAME='nmango.lan'
# ARIA2_RPC_TOKEN='TOKEN_HERE'
# SSH_PUBLIC_KEY='KEY_HERE'
# USB_DATA_DEVICE='usb11'
# TELEGRAM_BOT_TOKEN='TOKEN_HERE'
# TELEGRAM_CHATID='CHATID_HERE'
# WIFI_KEY='KEY_HERE'
#### .secrets.txt

clear
cat << "EOF"

┏┓    ┓ •  •
┏┛┓┏┏┏┣┓┓┏┓┓
┗┛┗┻┗┗┛┗┗┛┗┗


* Created by: Ameer Dawood
* This script runs my customized setup process for my travel router (OpenWrt)
=============================================================================

EOF


kill_tools() {
  tools="apk tar"
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

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHATID" ] || [ -z "$ARIA2_RPC_TOKEN" ] || [ -z "$SSH_PUBLIC_KEY" ] || [ -z "$HOSTNAME" ] || [ -z $WIFI_KEY ]; then
  echo "Some or all of the parameters are empty" >&2
  exit 1
fi

if [ ! -f /bin/bash ]; then echo "Please install bash." >&2; exit 1; fi

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
print_apk_busy() { printf "\e[91mapk Busy!\e[0m\n"; }
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
    sleep 1
  done
}


update_apk() {
  printf "   \e[34m•\e[0m Running apk update... "
  if [ -z "$(ls /var/cache/apk 2>/dev/null)" ]; then
    apk update >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  else
    print_already
  fi
}


setup_hostname() {
  printf "   \e[34m•\e[0m Setting up hostname... "
  if [ $(uci get system.@system[0].hostname) = $HOSTNAME ]; then
    print_already
  else
    uci set system.@system[0].hostname=$HOSTNAME && uci commit >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_timezone() {
  printf "   \e[34m•\e[0m Installing required tools... \n"
  pkgs="curl"
  for pkg in $pkgs; do
    printf "     \e[34m○\e[0m Installing $pkg... "
    if [ "$(apk info | grep ^$pkg$)" != "" ]; then
      print_already
    else
      apk add $pkg >/dev/null 2>&1 &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
  printf "   \e[34m•\e[0m Setting up timezone... "
  if [ "$(uci get system.@system[0].zonename 2>/dev/null)" = $TIMEZONE ]; then
    print_already
  else
    uci set system.@system[0].zonename=$TIMEZONE && uci set system.@system[0].timezone=$TIMEZONE_D && uci commit >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Syncronizing time... "
  http_date="$(curl -I http://www.google.com 2>/dev/null | grep Date)"
  time_only="$(echo $http_date | cut -d' ' -f6)"
  web_date="$(echo $http_date | cut -d' ' -f5)-$(echo $http_date | cut -d' ' -f4)-$(echo $http_date | cut -d' ' -f3) $(echo $time_only | cut -d':' -f1):$(echo $time_only | cut -d':' -f2)"
  system_date="$(date -u +"%Y-%b-%d %H:%M")"
  if [ "$web_date" = "$system_date" ]; then
    print_already
  else
    ntpd -p pool.ntp.org >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


notify_on_startup() {
  printf "   \e[34m•\e[0m Setting up notification on startup... "
  if [ "$(grep api.telegram.org /etc/rc.local)" != "" ]; then
    print_already
  else
    message="$HOSTNAME rebooted"
    sed -i 's/exit 0//g' /etc/rc.local && \
      echo -e "wget -qO- --post-data='chat_id=$TELEGRAM_CHATID&text=$message' 'https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage'" >> /etc/rc.local && \
      echo -e "\nexit 0" >> /etc/rc.local &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


change_default_shell() {
  printf "   \e[34m•\e[0m Installing bash shell... "
  if [ "$SHELL" = "/bin/bash" ]; then
    print_already
  else
    if [ "$(apk info | grep ^bash$)" != "" ]; then
      print_already
    else
      apk add bash >/dev/null 2>&1 &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
    printf "   \e[34m•\e[0m Changing default shell... "
    sed -i 's/\/bin\/ash/\/bin\/bash/g' /etc/passwd &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_ssh_keyfile() {
  printf "   \e[34m•\e[0m Setting up SSH key file... "
  if [ "$(grep -F "$SSH_PUBLIC_KEY" /etc/dropbear/authorized_keys 2>/dev/null)" != "" ]; then
    print_already
  else
    echo $SSH_PUBLIC_KEY > /etc/dropbear/authorized_keys 2>/dev/null &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


configure_wifi() {
  printf "   \e[34m•\e[0m Configuring Wifi... "
  if [ "$(uci get wireless.default_radio0.ssid)" = $WIFI_NAME ]; then
    print_already
  else
    uci set wireless.default_radio0.ssid=$WIFI_NAME && \
      uci set wireless.default_radio1.ssid=$WIFI_NAME && \
      uci set wireless.radio0.disabled='0' && \
      uci set wireless.radio1.disabled='0' && \
      uci set wireless.default_radio0.encryption='sae-mixed' && \
      uci set wireless.default_radio1.encryption='sae-mixed' && \
      uci set wireless.default_radio0.key=$WIFI_KEY && \
      uci set wireless.default_radio1.key=$WIFI_KEY && \
      uci set wireless.default_radio0.ocv='0' && \
      uci set wireless.default_radio1.ocv='0' && \
      uci commit && \
      wifi reload &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_cron() {
  printf "   \e[34m•\e[0m Setting up cron... "
  if [ -f /etc/crontabs/root ]; then
    print_already
  else
    (echo "") | crontab - &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


configure_usb_storage() {
  if [ "$(ls /dev/sd* 2>/dev/null)" = "" ]; then
    printf "   \e[34m•\e[0m Configuring USB storage... "
    print_notexist
  else
    if [ "$(mount | grep /mnt/$USB_DATA_DEVICE)" != "" ]; then
      printf "   \e[34m•\e[0m Configuring USB storage... "
      print_already
    else
      printf "   \e[34m•\e[0m Configuring USB storage... \n"
      pkgs="kmod-usb-storage kmod-usb-storage-uas kmod-usb3 usbutils block-mount e2fsprogs kmod-fs-ext4 blkid"
      for pkg in $pkgs; do
        printf "     \e[34m○\e[0m Installing $pkg... "
        if [ "$(apk info | grep ^$pkg$)" != "" ]; then
          print_already
        else
          apk add $pkg >/dev/null 2>&1 &
          bg_pid=$!
          show_progress $bg_pid
          wait $bg_pid
          assert_status
        fi
      done
      printf "   \e[34m•\e[0m Configuring mount... "
      device="$(blkid | grep $USB_DATA_DEVICE | head -1 | cut -d':' -f1)"
      block detect | uci import fstab && \
        uci set fstab.@mount[0].enabled='1' && \
        uci set fstab.@global[0].anon_mount='1' && \
        uci set fstab.@mount[0].target='/mnt/'$USB_DATA_DEVICE && \
        uci commit fstab && \
        sed -i 's/exit 0//g' /etc/rc.local && \
        echo -e "mount $device /mnt/$USB_DATA_DEVICE" >> /etc/rc.local && \
        echo -e "\nexit 0" >> /etc/rc.local && \
        /etc/init.d/fstab boot &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  fi
  printf "   \e[34m•\e[0m Installing required tools... \n"
  pkgs="blkid"
  for pkg in $pkgs; do
    printf "     \e[34m○\e[0m Installing $pkg... "
    if [ "$(apk info | grep ^$pkg$)" != "" ]; then
      print_already
    else
      apk add $pkg >/dev/null 2>&1 &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
  drive="$USB_DATA_DEVICE"
  printf "   \e[34m•\e[0m Setting up backup job for $drive... "
  script_file="${backup_script[$drive]}"
  if [ "$(blkid | grep $drive)" = "" ]; then
    print_notexist
  elif [ "$(crontab -l | grep '/mnt/'$drive'/'$script_file)" != "" ]; then
    print_already
  else
    (crontab -l && echo "${backup_schedule[$drive]} sudo /mnt/$drive/$script_file") | crontab - &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


configure_extroot() {
  printf "   \e[34m•\e[0m Configuring extroot... "
  if [ "$(df | grep $USB_DATA_DEVICE)" = "" ]; then
    print_notexist
  else
    device="$(blkid | grep $USB_DATA_DEVICE | head -1 | cut -d':' -f1)"
    if [ "$(df | grep /overlay$ | grep $device)" != "" ]; then
      print_already
    else
      eval $(block info $device | grep -o -e 'UUID="\S*"') && \
        eval $(block info | grep -o -e 'MOUNT="\S*/overlay"') && \
        uci -q delete fstab.extroot; \
        uci set fstab.extroot="mount" && \
        uci set fstab.extroot.uuid="$UUID" && \
        uci set fstab.extroot.target="$MOUNT" && \
        uci commit fstab && \
        ORIG="$(block info | sed -n -e '/MOUNT="\S*\/overlay"/s/:\s.*$//p')" && \
        uci -q delete fstab.rwm; \
        uci set fstab.rwm="mount" && \
        uci set fstab.rwm.device="$ORIG" && \
        uci set fstab.rwm.target="/rwm" && \
        uci commit fstab && \
        rm -rf /mnt/$USB_DATA_DEVICE/upper && \
        rm -rf /mnt/$USB_DATA_DEVICE/work && \
        tar -C $MOUNT -cf - . | tar -C /mnt/$USB_DATA_DEVICE -xf - &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
      if [ "$?" = "0" ]; then
        printf "\n\e[33mReboot required! Do you want to reboot now? (Y/N) \e[0m\n"
        read -r opt
        if [ "$opt" = "Y" ] || [ "$opt" = "y" ] || [ "$opt" = "yes" ] || [ "$opt" = "YES" ] || [ "$opt" = "Yes" ]; then
          echo "Rebooting now..."
          echo "Re-run the script to continue after reboot!"
          reboot
          sleep 10
        else
          echo "Exiting now... Re-run the script to continue!"
          exit 0
        fi
      fi
    fi
  fi
}


preserve_apk_lists() {
  printf "   \e[34m•\e[0m Configuring persistence of opkg lists... "
  if [ "$(grep /usr/lib/opkg/lists /etc/opkg.conf)" != "" ]; then
    print_already
  else
    sed -i -e "/^lists_dir\s/s:/var/opkg-lists$:/usr/lib/opkg/lists:" /etc/opkg.conf && \
      apk update >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


configure_swap() {
  printf "   \e[34m•\e[0m Creating swap file... "
  if [ -f /mnt/$USB_DATA_DEVICE/swap ]; then
    print_already
  else
    dd if=/dev/zero of=/mnt/$USB_DATA_DEVICE/swap bs=1M count=2048 >/dev/null 2>&1 && \
      mkswap /mnt/$USB_DATA_DEVICE/swap >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Configuring swap... "
  if [ "$(uci get fstab.swap.device 2>/dev/null)" = "/mnt/$USB_DATA_DEVICE/swap" ]; then
    print_already
  else
    uci -q delete fstab.swap; \
      uci set fstab.swap="swap" && \
      uci set fstab.swap.device="/mnt/$USB_DATA_DEVICE/swap" && \
      uci commit && \
      service fstab boot &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


disable_rebind_protection() {
  printf "   \e[34m•\e[0m Disabling rebind protections... "
  if [ "$(uci get dhcp.@dnsmasq[0].rebind_protection 2>/dev/null)" = "0" ]; then
    print_already
  else
    uci delete dhcp.@dnsmasq[0].rebind_localhost 2>/dev/null; \
      uci del dhcp.@dnsmasq[0].nonwildcard 2>/dev/null; \
      uci del dhcp.@dnsmasq[0].boguspriv 2>/dev/null; \
      uci del dhcp.@dnsmasq[0].filterwin2k 2>/dev/null; \
      uci del dhcp.@dnsmasq[0].filter_aaaa 2>/dev/null; \
      uci del dhcp.@dnsmasq[0].filter_a 2>/dev/null; \
      uci del dhcp.@dnsmasq[0].nonegcache 2>/dev/null; \
      uci set dhcp.@dnsmasq[0].rebind_protection='0' && \
      uci set dhcp.@dnsmasq[0].localservice='0' && \
      uci del dhcp.@dnsmasq[0].server 2>/dev/null; \
      uci add_list dhcp.@dnsmasq[0].server='/*.lan/192.168.88.11' && \
      uci commit dhcp && \
      /etc/init.d/dnsmasq restart >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_samba_shares() {
  printf "   \e[34m•\e[0m Installing samba... "
  if [ "$(apk info | grep ^luci-app-samba4$)" != "" ]; then
    print_already
  else
    apk add luci-app-samba4 >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Configuring samba... "
  if [ "$(uci get samba4.@sambashare[0].path 2>/dev/null)" = "/mnt/$USB_DATA_DEVICE" ]; then
    print_already
  else
    uci add samba4 sambashare >/dev/null 2>&1 && \
      uci set samba4.@sambashare[0].name=$USB_DATA_DEVICE && \
      uci set samba4.@sambashare[0].path='/mnt/'$USB_DATA_DEVICE && \
      uci set samba4.@sambashare[0].read_only='no' && \
      uci set samba4.@sambashare[0].guest_ok='yes' && \
      uci set samba4.@sambashare[0].create_mask='0666' && \
      uci set samba4.@sambashare[0].dir_mask='0777' && \
      uci set samba4.@sambashare[0].force_root='1' && \
      uci commit samba4 && \
      echo -e "[$USB_DATA_DEVICE]\n  path = /mnt/$USB_DATA_DEVICE\n  force user = root\n  force group = root\n  create mask = 0666\n  directory mask = 0777\n  read only = no\n  guest ok = yes" >> /etc/samba/smb.conf && \
      /etc/init.d/samba4 restart &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_rsync_daemon() {
  printf "   \e[34m•\e[0m Installing rsync... "
  if [ "$(apk info | grep ^rsync$)" != "" ]; then
    print_already
  else
    apk add rsync >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Configuring rsync... "
  if [ "$(grep /mnt/$USB_DATA_DEVICE /etc/rsyncd.conf 2>/dev/null)" != "" ]; then
    print_already
  else
    echo -e "pid file = /var/run/rsyncd.pid\nlog file = /var/log/rsyncd.log\nlock file = /var/run/rsync.lock\nuse chroot = no\nuid = root\ngid = root\nread only = no\n\n[$USB_DATA_DEVICE]\npath = /mnt/$USB_DATA_DEVICE\ncomment = $USB_DATA_DEVICE\nlist = yes\nhosts allow = 192.168.1.1/24,127.0.0.1" >> /etc/rsyncd.conf && \
      sed -i 's/exit 0//g' /etc/rc.local && \
      echo -e "rsync --daemon --config=/etc/rsyncd.conf --port=873" >> /etc/rc.local && \
      echo -e "\nexit 0" >> /etc/rc.local && \
      rsync --daemon --config=/etc/rsyncd.conf --port=873 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_aria2() {
  printf "   \e[34m•\e[0m Installing required packages for aria2... \n"
  pkgs="luci-app-aria2 webui-aria2"
  for pkg in $pkgs; do
    printf "     \e[34m○\e[0m Installing $pkg... "
    if [ "$(apk info | grep ^$pkg$)" != "" ]; then
      print_already
    else
      apk add $pkg >/dev/null 2>&1 &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
  printf "   \e[34m•\e[0m Configuring aria2... "
  if [ "$(uci get aria2.main.enabled 2>/dev/null)" = "1" ]; then
    print_already
  else
    if [ ! -f /mnt/$USB_DATA_DEVICE/.data/aria2/aria2.conf.main ]; then
      uci set aria2.main.enabled='1'
      uci set aria2.main.dir='/mnt/'$USB_DATA_DEVICE'/aria2'
      /etc/init.d/aria2 restart
      mkdir -p /mnt/$USB_DATA_DEVICE/.data/aria2
      cp /var/etc/aria2/aria2.conf.main /mnt/$USB_DATA_DEVICE/.data/aria2/aria2.conf.main
    fi
    uci set aria2.main.config_dir='/mnt/'$USB_DATA_DEVICE'/.data/aria2' && \
      /etc/init.d/aria2 restart && \
      uci set aria2.main.enabled='1' && \
      uci set aria2.main.dir='/mnt/'$USB_DATA_DEVICE'/aria2' && \
      uci set aria2.main.user='root' && \
      uci set aria2.main.max_concurrent_downloads='1' && \
      uci set aria2.main.rpc_auth_method='token' && \
      uci set aria2.main.rpc_secure='false' && \
      uci set aria2.main.rpc_secret=$ARIA2_RPC_TOKEN && \
      uci set aria2.main.max_overall_download_limit='200K' && \
      uci set aria2.main.check_certificate='false' && \
      uci set aria2.main.file_allocation='prealloc' && \
      uci commit aria2 && \
      sed -i 's/input-file=\/var\/etc\/aria2\/aria2.session.main/input-file=\/mnt\/usb11\/.data\/aria2\/aria2.session.mains/g' /mnt/$USB_DATA_DEVICE/.data/aria2/aria2.conf.main && \
      sed -i 's/save-session=\/var\/etc\/aria2\/aria2.session.main/save-session=\/mnt\/usb11\/.data\/aria2\/aria2.session.mains/g' /mnt/$USB_DATA_DEVICE/.data/aria2/aria2.conf.main && \
      /etc/init.d/aria2 restart &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


setup_adblock() {
  adblock_fast_configured=false
  printf "   \e[34m•\e[0m Installing required packages for adblocker... \n"
  pkgs="luci-app-adblock-fast gawk grep sed coreutils-sort"
  for pkg in $pkgs; do
    printf "     \e[34m○\e[0m Installing $pkg... "
    if [ "$(apk info | grep ^$pkg$)" != "" ]; then
      print_already
    else
      apk add --force-overwrite $pkg >/dev/null 2>&1 &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
  printf "   \e[34m•\e[0m Configuring adblocker... "
  if [ "$(uci get adblock-fast.config.enabled 2>/dev/null)" = "1" ]; then
    print_already
  else
    uci set adblock-fast.config.enabled='1' && \
      uci set adblock-fast.@file_url[0].enabled='1' && \
      uci commit adblock-fast &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
    if [ "$?" = "0" ]; then adblock_fast_configured=true; fi
  fi
  printf "   \e[34m•\e[0m Starting up adblocker... "
  if [ $adblock_fast_configured = false ]; then
    print_not_required
  else
    echo ""
    /etc/init.d/adblock-fast restart &
    bg_pid=$!
    wait $bg_pid
  fi
}


setup_nlbwmon() {
  printf "   \e[34m•\e[0m Installing nlbwmon... "
  if [ "$(apk info | grep ^luci-app-nlbwmon$)" != "" ]; then
    print_already
  else
    apk add luci-app-nlbwmon >/dev/null 2>&1 &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
  printf "   \e[34m•\e[0m Configuring nlbwmon... "
  if [ "$(uci get nlbwmon.@nlbwmon[0].commit_interval 2>/dev/null)" = "10m" ]; then
    print_already
  else
    uci set nlbwmon.@nlbwmon[0].commit_interval='10m' && \
      uci commit nlbwmon && \
      /etc/init.d/nlbwmon restart &
    bg_pid=$!
    show_progress $bg_pid
    wait $bg_pid
    assert_status
  fi
}


install_additionals() {
  printf "   \e[34m•\e[0m Installing additionals... \n"
  pkgs="screen htop nano openssh-sftp-server curl iperf3 luci-app-attendedsysupgrade bind-dig mc"
  for pkg in $pkgs; do
    printf "     \e[34m○\e[0m Installing $pkg... "
    if [ "$(apk info | grep ^$pkg$)" != "" ]; then
      print_already
    else
      apk add $pkg >/dev/null 2>&1 &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
}


install_externals() {
  printf "   \e[34m•\e[0m Installing externals... \n"
  files="$(ls /mnt/$USB_DATA_DEVICE/apk/*.apk 2>/dev/null)"
  for file in $files; do
    pkg="$(basename $file | sed 's/^\([a-z0-9.+-]\+\)-[0-9].*/\1/')"
    printf "     \e[34m○\e[0m Installing $pkg... "
    if [ "$(apk info | grep ^$pkg$)" != "" ]; then
      print_already
    else
      apk add --allow-untrusted $file >/dev/null 2>&1 &
      bg_pid=$!
      show_progress $bg_pid
      wait $bg_pid
      assert_status
    fi
  done
}


update_apk
setup_hostname
setup_timezone
notify_on_startup
change_default_shell
setup_ssh_keyfile
configure_wifi
setup_cron
configure_usb_storage
configure_extroot
# preserve_apk_lists
configure_swap
disable_rebind_protection
setup_samba_shares
setup_rsync_daemon
setup_aria2
setup_adblock
setup_nlbwmon
install_additionals
install_externals


echo "" # just an empty line before we end