#!/bin/bash

# Configuration
EL_VERSION=9
PHP_VERSION=8.1
NODE_VERSION=18
ROUNDCUBE_VERSION=1.5.3

USER=user
DB_USER=user
DB_NAME=database
DOMAIN=

EMAIL_ADDRESS=test@example.com


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


# Purpose specific settings
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
    PKGS=$PKGS" postfix dovecot opendkim opendkim-tools opendmarc spamassassin"
fi

echo "Is this machine for development?"
echo -e "(Y/N):\c"
read DEV
if [[ $DEV == 'y' || $DEV == 'Y' ]]; then
    DEV=1
    PKGS=$PKGS" powerline-fonts" # TODO it seems install through PM does not work
fi

echo "Is this machine for desktop?"
echo -e "(Y/N):\c"
read DESK
if [[ $DESK == 'y' || $DESK == 'Y' ]]; then
    DESK=1
    PKGS=$PKGS" code" # NOTE google-chrome-stable" Exclude until Google fix SHA1 signature
fi

if [[ $WEB == 1 || $MAIL == 1 ]]; then
    PKGS=$PKGS" php-fpm php-bcmath php-ctype php-curl php-dom php-fileinfo php-json php-mbstring php-openssl php-pcre php-pdo php-xml php-tokenizer php-pgsql \
        php-session php-sockets php-filter php-intl php-iconv php-zip php-exif"
fi


# Register system
if [ $OS = "rhel" ]; then
    echo $SEP
    sudo subscription-manager register
    sudo subscription-manager attach --auto
fi


# New user
if [[ $DESK != 1 ]]; then
    echo $SEP
    sudo adduser $USER
    echo "Make new user a sudoer?"
    echo -e "(Y/N):\c"
    read SUDO
    if [[ $SUDO == 'y' || $SUDO == 'Y' ]]; then
        sudo usermod -aG wheel $USER
    fi
fi


# First update and basic packages
echo $SEP
sudo $PM update -y
sudo $PM install -y vim git zsh util-linux-user yum-utils policycoreutils-python-utils fail2ban

# Extra repos
if [ $OS = "rhel" ]; then
    echo $SEP

    # EPEL
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$EL_VERSION.noarch.rpm
    crb enable

    # Docker-ce
    # Currently not supported, podman is not an option yet, but can use centos version for the moment
    if [[ $VPN == 1 ]]; then
        echo $SEP
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        # podman conflict with docker
        sudo $PM remove -y podman buildah
    fi

    # Desktop Application
    if [[ $DESK == 1 ]]; then
        echo $SEP
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        # NOTE Google is still using SHA1 for RPM signature, and GPG verification will fail on EL9, skip for now
        #sudo sh -c 'echo -e "[google-chrome]\nname=google-chrome\nbaseurl=https://dl.google.com/linux/chrome/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\ngpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub" > /etc/yum.repos.d/google-chrome.repo'
    fi
fi

# Version specific
echo $SEP
sudo $PM module enable -y php:$PHP_VERSION
sudo $PM module enable -y nodejs:$NODE_VERSION

# Install packages
echo $SEP
sudo $PM update -y
sudo $PM install -y $PKGS


# Non-PM installation
# Oh-my-zsh
echo $SEP
sudo sh -c 'cd /root;sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' root
# Some tweaks on theme
sudo sed -i "s;ZSH_THEME.*;ZSH_THEME=\"agnoster\";g" /root/.zshrc
sudo sed -i "s;prompt_segment blue \$CURRENT_FG '%~';prompt_segment blue \$CURRENT_FG '%1~';g" /root/.oh-my-zsh/themes/agnoster.zsh-theme
sudo chsh -s /bin/zsh root

echo $SEP
sudo sh -c 'cd /home/$USER;sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' $USER
# Some tweaks on theme
sudo sed -i "s;ZSH_THEME.*;ZSH_THEME=\"agnoster\";g" /home/$USER/.zshrc
sudo sed -i "s;prompt_segment blue \$CURRENT_FG '%~';prompt_segment blue \$CURRENT_FG '%1~';g" /home/$USER/.oh-my-zsh/themes/agnoster.zsh-theme
sudo chsh -s /bin/zsh $USER


if [[ $WEB == 1 ]]; then
    # Composer
    echo $SEP
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    sudo mv composer.phar /usr/bin/composer
fi

if [[ $DEV == 1 ]]; then
    # Deployer
    echo $SEP
    curl -LO https://deployer.org/deployer.phar
    sudo mv deployer.phar /usr/bin/dep
    sudo chmod +x /usr/bin/dep
fi

if [[ $MAIL == 1 ]]; then
    curl -LO https://github.com/roundcube/roundcubemail/releases/download/$ROUNDCUBE_VERSION/roundcubemail-$ROUNDCUBE_VERSION-complete.tar.gz
fi


# Configuration
# Fail2Ban
# TODO

if [[ $WEB == 1 || $MAIL == 1 ]]; then
    # User
    echo $SEP
    sudo adduser deploy
    sudo usermod -aG nginx deploy
    sudo usermod -aG nginx $USER

    # Directory
    echo $SEP
    sudo mkdir /home/site
    sudo chown nginx:nginx /home/site
    sudo chmod 775 /home/site

    if [[ $MAIL == 1 ]]; then
        sudo tar -xf roundcubemail-$ROUNDCUBE_VERSION-complete.tar.gz -C /home/site
        sudo mv /home/site/roundcubemail-$ROUNDCUBE_VERSION /home/site/roundcubemail
        sudo mv /home/site/roundcubemail/config/config.inc.php.sample /home/site/roundcubemail/config/config.inc.php
        rm roundcubemail-$ROUNDCUBE_VERSION-complete.tar.gz
    fi

    # Nginx
    echo $SEP
    CONF=$(cat conf/nginx-main.conf)

    if [[ $WEB == 1 ]]; then
        VHOST_CONF=$(cat conf/nginx-server.conf)
        if [[ ! -z $DOMAIN ]]; then
            VHOST_CONF=$(echo $VHOST_CONF | sed "s;server_name _;server_name www.$DOMAIN;g")
        fi
        VHOST_CONF=$(echo $VHOST_CONF | sed "s;root /path/to/site;root /home/site/path;g")

        CONF=$(echo $CONF | sed "s;#SCRIPTANCHOR;$VHOST_CONF \n#SCRIPTANCHOR;g")
    fi

    if [[ $MAIL == 1 ]]; then
        VHOST_CONF=$(cat conf/nginx-server.conf)
        if [[ ! -z $DOMAIN ]]; then
            VHOST_CONF=$(echo $VHOST_CONF | sed "s;server_name _;server_name mail.$DOMAIN;g")
        fi
        VHOST_CONF=$(echo $VHOST_CONF | sed "s;root /path/to/site;root /home/site/roundcubemail;g")

        CONF=$(echo $CONF | sed "s;#SCRIPTANCHOR;$VHOST_CONF \n#SCRIPTANCHOR;g")
    fi

    echo $CONF | sudo tee /etc/nginx/nginx.conf

    # PHP
    echo $SEP
    sudo sed -i "s;user = apache;user = nginx;g" /etc/php-fpm.d/www.conf
    sudo sed -i "s;group = apache;group = nginx;g" /etc/php-fpm.d/www.conf
    sudo sed -i "s;\;listen.owner = nobody;listen.owner = nginx;g" /etc/php-fpm.d/www.conf
    sudo sed -i "s;\;listen.group = nobody;listen.group = nginx;g" /etc/php-fpm.d/www.conf
    sudo sed -i "s;\;listen.mode = 0660;listen.mode = 0660;g" /etc/php-fpm.d/www.conf
    sudo sed -i "s;listen.acl_users = apache,nginx;\;listen.acl_users = apache,nginx;g" /etc/php-fpm.d/www.conf

    # PostgreSQL
    echo $SEP
    sudo postgresql-setup --initdb
    sudo echo -e "\n" >> /var/lib/pgsql/data/pg_hba.conf

    if [[ $WEB == 1 ]]; then
        sudo -Hiu postgres createuser -P $DB_USER
        sudo -Hiu postgres createdb -O $DB_USER -E UNICODE $DB_NAME
        echo "host    $(printf "%-15s" $DB_NAME) $(printf "%-15s" $DB_USER) 127.0.0.1/32            md5" | sudo tee -a /var/lib/pgsql/data/pg_hba.conf > /dev/null
    fi

    if [[ $MAIL == 1 ]]; then
        sudo -Hiu postgres createuser -P roundcube
        sudo -Hiu postgres createdb -O roundcube -E UNICODE roundcubemail
        echo "host    roundcubemail   roundcube       127.0.0.1/32            md5" | sudo tee -a /var/lib/pgsql/data/pg_hba.conf > /dev/null
        sudo sed -i "s;mysql://roundcube:pass@localhost/roundcubemail;pgsql://roundcube:pass@127.0.0.1/roundcubemail;g" /home/site/roundcubemail/config/config.inc.php

        echo "!!Please replace your password for Roundcube DB after script finished!!"
    fi

    if [[ $MAIL == 1 ]]; then
        # Postfix
        sudo sed -i "s;#myhostname = virtual.domain.tld;myhostname = mail.$DOMAIN;g" /etc/postfix/main.cf
        sudo sed -i "s;#mydomain = domain.tld;mydomain = $DOMAIN;g" /etc/postfix/main.cf
        sudo sed -i "s;#myorigin = \$mydomain;myorigin = \$mydomain" /etc/postfix/main.cf
        sudo sed -i "s;^mydestination = \$myhostname, localhost.\$mydomain, localhost;#mydestination = \$myhostname, localhost.\$mydomain, localhost;g" /etc/postfix/main.cf
        sudo sed -i "s;#mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain;mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain;g" /etc/postfix/main.cf

        # Dovecot
        sudo sed -i "s;#protocols = imap pop3 lmtp submission;protocols = imap pop3 lmtp;g" /etc/dovecot/dovecot.conf
        sudo sed -i "s;#listen = *, ::;listen = *, ::;g" /etc/dovecot/dovecot.conf

        # OpenDKIM
        # TODO

    fi
fi


# SSL
if [[ ($WEB == 1 || $MAIL == 1) && $DEV != 1 ]]; then
    # Nginx
    sudo certbot --nginx --non-interactive --agree-tos --domains www.$DOMAIN,mail.$DOMAIN --email $EMAIL_ADDRESS

    # Postfix
    echo "smtpd_use_tls = yes" | sudo tee -a /etc/postfix/main.cf
    sudo sed -i "s;smtpd_tls_cert_file = /etc/pki/tls/certs/postfix.pem;smtpd_tls_cert_file = /etc/letsencrypt/live/$DOMAIN/fullchain.pem;g" /etc/postfix/main.cf
    sudo sed -i "s;smtpd_tls_key_file = /etc/pki/tls/private/postfix.key;smtpd_tls_key_file = /etc/letsencrypt/live/$DOMAIN/privkey.pem;g" /etc/postfix/main.cf

    # Dovecot
    sudo sed -i "s;ssl_cert = </etc/pki/dovecot/certs/dovecot.pem;ssl_cert = </etc/letsencrypt/live/$DOMAIN/fullchain.pem;g" /etc/dovecot/conf.d/10-ssl.conf
    sudo sed -i "s;ssl_key = </etc/pki/dovecot/private/dovecot.pem;ssl_key = </etc/letsencrypt/live/$DOMAIN/privkey.pem;g" /etc/dovecot/conf.d/10-ssl.conf
fi


# SELinux
# TODO
sudo setenforce 1
sudo setsebool -P httpd_can_network_connect 1


# Service
if [[ $WEB == 1 ]]; then
    echo $SEP
    sudo systemctl enable --now nginx
    sudo systemctl enable --now php-fpm
    sudo systemctl enable --now postgresql
fi

if [[ $MAIL == 1 ]]; then
    echo $SEP
    sudo systemctl enable --now postfix
    sudo systemctl enable --now php-fpm
    sudo systemctl enable --now postgresql
fi
