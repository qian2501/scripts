#!/bin/bash

# Configuration
USER=user
EL_VERSION=9
PHP_VERSION=8.1
NODE_VERSION=18


# Var
SEP=----------


# Get distro name
OS=$(awk -F'=' '/^ID=/ {print tolower($2)}' /etc/*-release)
# Some OS contains d-quotes, which need to remove
OS=${OS#*\"}
OS=${OS%\"*}

# Get package manager and package list from distro
# Leave a space at the end for append
# OSs other than RHEL will exit fail
if [ $OS = "rhel" ]; then
    PM=dnf
    PKGS=""
else
    exit 1
fi


# Purpose specific packages
echo "Is this machine for web development or web server?"
echo -e "(Y/N):\c"
read WEB
if [[ $WEB == 'y' || $WEB == 'Y' ]]; then
    WEB=1
    PKGS=$PKGS" nginx php nodejs postgresql-server python3-certbot python3-certbot-nginx"
fi

echo "Is this machine for VPN?"
echo -e "(Y/N):\c"
read VPN
if [[ $VPN == 'y' || $VPN == 'Y' ]]; then
    VPN=1
fi

echo "Is this machine for email server?"
echo -e "(Y/N):\c"
read MAIL
if [[ $MAIL == 'y' || $MAIL == 'Y' ]]; then
    MAIL=1
    PKGS=$PKGS" postfix dovecot"
fi

echo "Is this machine for development?"
echo -e "(Y/N):\c"
read DEV
if [[ $DEV == 'y' || $DEV == 'Y' ]]; then
    DEV=1
    PKGS=$PKGS" powerline-fonts"
fi

echo "Is this machine for desktop?"
echo -e "(Y/N):\c"
read DESK
if [[ $DESK == 'y' || $DESK == 'Y' ]]; then
    DESK=1
    PKGS=$PKGS" code" #google-chrome-stable" Exclude until Google fix SHA1 signature
fi

if [[ $WEB == 1 || $MAIL == 1 ]]; then
    PKGS=$PKGS" php-fpm php-bcmath php-ctype php-curl php-dom php-fileinfo php-json php-mbstring php-openssl php-pcre php-pdo php-xml php-tokenizer php-pgsql \
        php-session php-sockets php-filter php-intl php-iconv php-zip php-exif"
fi


# Register system
if [ $OS = "rhel" ]; then
    sudo subscription-manager register
    sudo subscription-manager attach --auto
fi


# New user
if [[ $DESK != 1 ]]; then
    adduser $USER
    echo "Make new user a sudoer?"
    echo -e "(Y/N):\c"
    read SUDO
    if [[ $SUDO == 'y' || $SUDO == 'Y' ]]; then
        SUDO=1
        sudo usermod -aG wheel $USER
    fi
fi


# First update
# "dnf update" and "apt update" behave differently
echo $SEP
sudo $PM update -y
sudo $PM install -y vim git zsh util-linux-user yum-utils policycoreutils-python-utils

# Extra repos
if [ $OS = "rhel" ]; then
    echo $SEP

    # EPEL
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$EL_VERSION.noarch.rpm
    crb enable

    # Docker-ce
    # Currently not supported, podman is not an option yet, but can use centos version for the moment
    if [[ $VPN == 1 ]]; then
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        # podman conflict with docker
        sudo $PM remove -y podman buildah
    fi

    # Desktop Application
    if [[ $DESK == 1 ]]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        # NOTE Google is still using SHA1 for RPM signature, and GPG verification will fail on EL9
        sudo sh -c 'echo -e "[google-chrome]\nname=google-chrome\nbaseurl=https://dl.google.com/linux/chrome/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\ngpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub" > /etc/yum.repos.d/google-chrome.repo'
    fi
fi

# Version specific
sudo $PM module enable -y php:$PHP_VERSION
sudo $PM module enable -y nodejs:$NODE_VERSION

# Install packages
echo $SEP
sudo $PM update -y
sudo $PM install -y $PKGS


# Non-PM installation
# Oh-my-zsh
echo $SEP
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
# Some tweaks on theme
sed -i "s;ZSH_THEME.*;ZSH_THEME=\"agnoster\";g" .zshrc
sed -i "s;prompt_segment blue \$CURRENT_FG '%~';prompt_segment blue \$CURRENT_FG '%1~';g" .oh-my-zsh/themes/agnoster.zsh-theme

echo $SEP
su -c 'cd /home/$USER;sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' $USER
# Some tweaks on theme
sed -i "s;ZSH_THEME.*;ZSH_THEME=\"agnoster\";g" /home/$USER/.zshrc
sed -i "s;prompt_segment blue \$CURRENT_FG '%~';prompt_segment blue \$CURRENT_FG '%1~';g" /home/$USER/.oh-my-zsh/themes/agnoster.zsh-theme


if [[ $WEB == 1 ]]; then
    # Composer
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    sudo mv composer.phar /usr/bin/composer
fi

if [[ $DEV == 1 ]]; then
    # Deployer
    curl -LO https://deployer.org/deployer.phar
    sudo mv deployer.phar /usr/bin/dep
    sudo chmod +x /usr/bin/dep
fi


# Services
# Configuration
# TODO


# Auto-run
if [[ $WEB == 1 ]]; then
    sudo systemctl enable --now nginx
    sudo systemctl enable --now php-fpm
    sudo postgresql-setup --initdb
    sudo systemctl enable --now postgresql
fi

