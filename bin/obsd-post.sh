#!/bin/sh
# --------------------------------
# jwh 2022-04-20

USAGE="Usage: obsd-post.sh -ihv args"

set -e

echo "perform fw_update"
fw_update

echo "perform syspatch"
syspatch

echo "copy doas and wscons example conf into place"
cp /etc/examples/doas.conf /etc
cp /etc/examples/wsconsctl.conf /etc

echo "updates to doas and wscons"
sed -i 's/permit/permit persist/' /etc/doas.conf
echo 'keyboard.map+="keysym Caps_Lock = Control_L"' >> /etc/wsconsctl.conf

echo "if laydros exists, add groups staff and operator"
if id -u laydros >/dev/null 2>&1; then
    usermod -G staff,operator laydros
else
    echo "no user laydros on system"
fi

echo "update fstab for noatime and softdep"
cp /etc/fstab /etc/fstab.bak
sed -i 's/rw/rw,noatime,softdep/' /etc/fstab

echo "disable xconsole in xenodm"
sed -i 's/xconsole/#xconsole/' /etc/X11/xenodm/Xsetup_0

# ----- package install
mkdir -p /var/syncthing

BASE_PKGS="git curl wget yadm exa nnn htop detox ncdu rsync ripgrep bat " \
BASE_PKGS="$BASE_PKGS delta"
echo "add base packages: $BASE_PKGS"
pkg_add $BASE_PKGS

DESKTOP_PKGS="syncthing firefox meld mpv irssi pandoc cyrus-sasl--"
DESKTOP_PKGS="$DESKTOP_PKGS isync notmuch msmtp neofetch aria2 sxiv "
DESKTOP_PKGS="$DESKTOP_PKGS libqrencode zathura abook audacious cmus lynx nmap"
DESKTOP_PKGS="$DESKTOP_PKGS password-store mutt--gpgme-sasl"
echo "add desktop packages: $DESKTOP_PKGS"
pkg_add $DESKTOP_PKGS
        

echo "add syncthing init for laydros"
cp /etc/rc.d/syncthing{,_laydros}
sed -i 's/daemon_user=_syncthing/daemon_user="laydros"/' /etc/rc.d/syncthing_laydros
rcctl enable syncthing_laydros

