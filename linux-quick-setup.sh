#!/bin/bash
# Should execute WITHOUT sudo

# Var
SEP=----------

# Get distro name
OS=$(awk -F'=' '/^ID=/ {print tolower($2)}' /etc/*-release)
# For CentOS the name will contain d-quotes, which need to be removed
OS=${OS#*\"}
OS=${OS%\"*}

# Get package manager and package list from distro
# Leave a space at the end for expansion
if [ $OS = "ubuntu" ]||[ $OS = "debian" ]; then
    PM=apt
    PKGS="git zsh gcc make curl "
elif [ $OS = "centos" ]||[ $OS = "rhel" ]; then
    PM=yum
    PKGS="git zsh gcc make curl "
elif [ $OS = "opensuse-leap" ] then
    PM=zypper
    PKGS="git zsh gcc make curl "
fi

# First update
# "yum update" and "apt update" behavior is different
echo $SEP
sudo $PM update -y
sudo $PM upgrade -y
# Basic packages
echo $SEP
sudo $PM install -y $PKGS

# Powerline fonts
echo $SEP
if [ $OS = "ubuntu" ]||[ $OS = "debian" ]; then
    sudo $PM install -y fonts-powerline
else
    # clone
    git clone https://github.com/powerline/fonts.git --depth=1
    # install
    cd fonts
    ./install.sh
    # clean-up a bit
    cd ..
    rm -rf fonts
fi

# Oh-my-zsh
echo $SEP
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# Some tweaks on theme
sed -i "s;ZSH_THEME.*;ZSH_THEME=\"agnoster\";g" .zshrc
sed -i "s;prompt_segment blue \$CURRENT_FG '%~';prompt_segment blue \$CURRENT_FG '%1~';g" .oh-my-zsh/themes/agnoster.zsh-theme
