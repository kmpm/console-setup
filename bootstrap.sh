#!/usr/bin/env bash

PKGS=""

lsbdetect() {
    
    if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
        echo Detected lsb-release
        OSDIST=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'// | tr '[:upper:]' '[:lower:]')
        OSVERSION=$(lsb_release -r | cut -d: -f2 | sed s/'^\t'// | tr '[:upper:]' '[:lower:]')
        return 0
    fi
    return 1
}

osreleasedetect() {
    if [ -f /etc/os-release ]; then 
        echo Detected os-release
        # cat /etc/os-release
        OSVERSION=$(awk -F'=' '/VERSION_ID/ {print $2}' /etc/os-release | sed 's/\"//g')
        OSDIST=$(awk -F'=' '/ID_LIKE/ {print $2}' /etc/os-release | tr '[:upper:]' '[:lower:]')
        # TODO: if ID_LIKE is nothing then get ID
        return 0
    fi
    return 1
}

hwdetect() {
    HWMODEL=''
    HWMACHINE=$(uname -m)
    if [ -f /proc/device-tree/model ]; then
            # probably Raspberry PI
        read HWMODEL <  /proc/device-tree/model
    fi
    # echo model $(cat /proc/device-tree/model)
}

osdetect() {
    # https://askubuntu.com/questions/459402/how-to-know-if-the-running-platform-is-ubuntu-or-centos-with-help-of-a-bash-scri
    OSDIST='unknown'
    OSVERSION=''
    OSWSL=false
    OSRELEASE=''
    
    
    if [[ $OSTYPE == darwin* ]]; then
        echo is on a Mac... bailing out
        exit -1
    elif [[ $OSTYPE == linux-gnu* ]]; then 
        echo Detected OSTYPE linux-gnu
        read $OSRELEASE </proc/sys/kernel/osrelease
        
        if [ ! -z ${WSL_DISTRO_NAME+x} ]; then
            # https://stackoverflow.com/questions/38859145/detect-ubuntu-on-windows-vs-native-ubuntu-from-bash-script
            # https://stackoverflow.com/questions/38086185/how-to-check-if-a-program-is-run-in-bash-on-ubuntu-on-windows-and-not-just-plain
            OSWSL=true
        fi
        if lsbdetect ; then
            return 0
        elif osreleasedetect ; then
            return 0
        else
            echo Error. Undetectable dist.
            exit -1
        fi
    fi
}

confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

checkpkg() {
    if ! command -v $1 &> /dev/null ; then
        PKGS="$PKGS $2"
    fi
}


osdetect
hwdetect
echo OSDIST: $OSDIST, OSVERSION: $OSVERSION, OSWSL: $OSWSL OSRELEASE: $OSRELEASE
echo HWMACHINE: $HWMACHINE, HWMODEL: $HWMODEL

checkpkg git git
checkpkg tmux tmux
checkpkg vim vim
checkpkg unzip unzip

echo PKGS: $PKGS



if [[ $OSDIST == ubuntu || $OSDIST == debian ]]; then
    if [[ "${#PKGS}" -gt 0 ]]; then
        # check last apt update
        # https://askubuntu.com/questions/410247/how-to-know-last-time-apt-get-update-was-executed
        # https://stackoverflow.com/questions/19463334/how-to-get-time-since-file-was-last-modified-in-seconds-with-bash
        PKGCACHE=/var/cache/apt/pkgcache.bin
        TIME_DIFF=$(($(date +%s) - $(date +%s -r $PKGCACHE)))
        if [[ "${TIME_DIFF}" -gt 43200 ]] ; then
            echo
            echo "It's been >12 hours since apt update was ran."
            sudo apt-get update -y
        fi
        echo 
        echo "Installing packages $PKGS"
        sudo apt-get install -y $PKGS
    else
        echo "- All packages already installed."
    fi
fi

if [[ $HWMODEL == Raspberry* ]]; then
    wget -O /tmp/console-setup.zip https://github.com/kmpm/console-setup/archive/master.zip
    if [ ! -d $HOME/bin ]; then mkdir -p $HOME/bin; fi
    if [ ! -f $HOME/.tmux.conf ]; then 
        unzip -nj /tmp/console-setup.zip console-setup-master/files/.tmux.conf $HOME 
    fi
    if [ ! -f $HOME/bin/status.sh ]; then
        unzip -nj /tmp/console-setup.zip console-setup-master/files/status.sh -d $HOME/bin
        chmod +x $HOME/bin/status.sh
    fi
    
    if ! command -v argonone-config &> /dev/null ; then
        echo "Install script for Argon One?"
        if confirm ; then curl https://download.argon40.com/argon1.sh | bash fi
fi

# TODO: Raspberry Pi 4 only, check HWMODEL
# if ! $(grep -q "dtoverlay=dwc2" /boot/config.txt); then
#     echo "Setting up USB gadget mode"
#     wget -O /tmp/rpi4-usb.sh https://raw.githubusercontent.com/kmpm/rpi-usb-gadget/master/rpi4-usb.sh
#     chmod +x /tmp/rpi4-usb.sh
#     /tmp/rpi4-usb.sh
# else
#     echo "- USB gadget mode already configured"
# fi


