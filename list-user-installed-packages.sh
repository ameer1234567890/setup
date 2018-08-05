#!/bin/sh

## thread: https://forum.openwrt.org/viewtopic.php?id=42739
## source: https://gist.github.com/devkid/8d4c2a5ab62e690772f3d9de5ad2d978

FLASH_TIME=$(opkg status busybox | awk '/Installed-Time/ {print $2}')
LIST_INSTALLED=$(opkg list-installed | awk '{print $1}')

PACKAGES_2_INSTALL="/tmp/pack2install.txt"
SYSTEM_INSTALLED="/tmp/installedwithsystem.txt"

if [ -e "$PACKAGES_2_INSTALL" ]; then
	rm -f "$PACKAGES_2_INSTALL"
	touch "$PACKAGES_2_INSTALL"
else
	touch "$PACKAGES_2_INSTALL"
fi

if [ -e "$SYSTEM_INSTALLED" ]; then
	rm -f "$SYSTEM_INSTALLED"
	touch "$SYSTEM_INSTALLED"
else
	touch "$SYSTEM_INSTALLED"
fi

echo
echo "Getting a list of the current manually installed packages (this may take a minute or two):"
echo
for i in $LIST_INSTALLED; do
	if [ "$(opkg status $i | awk '/Installed-Time:/ {print $2}')" != "$FLASH_TIME" ]; then
		echo $i | tee -a "$PACKAGES_2_INSTALL"
	else
		echo $i >> "$SYSTEM_INSTALLED"
	fi
done

echo
echo "The list of current MANUALLY installed packages ready at: \"$PACKAGES_2_INSTALL\""
echo
echo "Just to make sure, a list of packages installed by the SYSTEM at FLASH TIME is ready at: \"$SYSTEM_INSTALLED\""
echo

exit 0
