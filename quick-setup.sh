#!/bin/bash
# Should execute WITHOUT sudo

# Var
SEP=----------
WEB=0
VPN=0

# Configuration
USER=user
EL_VERSION=8
NVM_VERSION="v0.39.1"
NODE_VERSION=14

# Get distro name
OS=$(awk -F'=' '/^ID=/ {print tolower($2)}' /etc/*-release)
# Some OS will contain d-quotes, which need to be removed
OS=${OS#*\"}
OS=${OS%\"*}

# Get package manager and package list from distro
# Leave a space at the end for append
# OSs other than RHEL will exit fail
if [ $OS = "rhel" ]; then
    PM=dnf
    PKGS="vim git zsh util-linux-user policycoreutils-python-utils "
else
    exit 1
fi


# Purpose specific packages
echo "Is this machine for web development or web server?"
echo -e "(Y/N):\c"
read WEB
if [[ $WEB == 'y' || $WEB == 'Y' ]]; then
    WEB=1
    PKGS=$PKGS"nginx postgresql-server npm php-ctype php-mbsting php-bcmath php-cli php-curl php-xml php-json php-tokenizer php-zip php-pdo php-pgsql python3-certbot python3-certbot-nginx "
fi

echo "Is this machine for VPN?"
echo -e "(Y/N):\c"
read VPN
if [[ $VPN == 'y' || $VPN == 'Y' ]]; then
    VPN=1
    PKGS=$PKGS"docker-ce docker-ce-cli containerd.io "
fi

echo "Is this machine for remote development?"
echo -e "(Y/N):\c"
read DEV
if [[ $DEV == 'y' || $DEV == 'Y' ]]; then
    DEV=1
    PKGS=$PKGS"powerline-fonts "
fi

echo "Is this machine for desktop?"
echo -e "(Y/N):\c"
read DESK
if [[ $DESK == 'y' || $DESK == 'Y' ]]; then
    DESK=1
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


# Extra repos
if [ $OS = "rhel" ]; then
    echo $SEP

    # EPEL
    sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$EL_VERSION.noarch.rpm

    # Docker-ce
    if [[ $VPN == 1 ]]; then
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    fi
fi


# First update
# "dnf update" and "apt update" behave differently
echo $SEP
sudo $PM update -y

# Install packages
echo $SEP
sudo $PM install -y $PKGS


# Non-standard installation
# Oh-my-zsh
echo $SEP
# TODO install as new user
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# Some tweaks on theme
sed -i "s;ZSH_THEME.*;ZSH_THEME=\"agnoster\";g" .zshrc
sed -i "s;prompt_segment blue \$CURRENT_FG '%~';prompt_segment blue \$CURRENT_FG '%1~';g" .oh-my-zsh/themes/agnoster.zsh-theme

if [[ $WEB == 1 ]]; then
    # Composer
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php -r "if (hash_file('sha384', 'composer-setup.php') === '906a84df04cea2aa72f40b5f787e49f22d4c2f19492ac310e8cba5b96ac8b64115ac402c8cd292b8a03482574915d1a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    sudo mv composer.phar /usr/bin/composer

    # nvm
    # TODO install as new user
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash

    if [ -f ~/.zshrc ]; then
        . ~/.zshrc
    fi

    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi

    nvm install $NODE_VERSION
    nvm use $NODE_VERSION
fi

if [[ $DEV == 1 ]]; then
    # code-server
    curl -fsSL https://code-server.dev/install.sh | sh

    # Deployer
    curl -LO https://deployer.org/deployer.phar
    sudo mv deployer.phar /usr/bin/dep
    sudo chmod +x /usr/bin/dep
fi


# Services
if [[ $WEB == 1 ]]; then
    sudo systemctl enable --now nginx
    sudo systemctl enable --now php-fpm
    sudo postgresql-setup --initdb
    sudo systemctl enable --now postgresql
fi

if [[ $DEV == 1 ]]; then
    sudo systemctl enable --now code-server@$USER
fi

