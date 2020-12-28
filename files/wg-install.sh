#!/usr/bin/env bash

sudo apt install raspberrypi-kernel-headers libelf-dev build-essential git qrencode

install() {
    src=$1
    if [ -d $src ]; then
	    make -C $src/src -j $(nproc)
	    sudo make -C $src/src install
    else
	    echo "Missing folder $src"
    fi
}

clone() {
	src=$1
	if [ ! -d $src ]; then
		git clone https://git.zx2c4.com/$src
		install $src
		return 0
	fi
	pushd $src
	changed=0
	git remote update && git status -uno | grep -q 'Your branch is behind' && changed=1
	if [ $changed = 1 ]; then
	    git pull
	    popd
	    echo "Updated successfully";
	    install $src
	else
	    popd
	    echo "Up-to-date"
	fi
}

clone wireguard-linux-compat
clone wireguard-tools

echo "Updating /etc/sysctl.conf with net.ipv4.ip_forward=1"
sudo sed -i 's/[# ]*net\.ipv4\.ip_forward *= *[01]/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
# grep "ip_forward" /etc/sysctl.conf
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null

if [ ! -d /etc/wireguard ]; then
	sudo mkdir /etc/wireguard
	sudo umask 077 /etc/wireguard
	wg genkey | sudo tee /etc/wireguard/server_key | wg pubkey | sudo tee /etc/wireguard/server_key.pub
	wg genkey | sudo tee /etc/wireguard/peer1_key | wg pubkey | sudo tee /etc/wireguard/peer1_key.pub
fi

