#!/bin/bash

# Configuration
EL_VERSION=9
PHP_VERSION=8.1
NODE_VERSION=18
ROUNDCUBE_VERSION=1.5.3

SSH_PORT=22
NEWUSER=user
DB_USER=user
DB_NAME=db
DOMAIN=

EMAIL_ADDRESS=someone@example.com


# Var
SEP=----------


# Get distro name
OS=$(awk -F'=' '/^ID=/ {print tolower($2)}' /etc/*-release)
# Some OS contains d-quotes, which need to remove
OS=${OS#*\"}
OS=${OS%\"*}

# Get package manager and package list from distro
# OSs other than RHEL will exit fail as not supported
if [ $OS = "rhel" ]; then
    PM=dnf
    PKGS="fail2ban"
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
    sudo adduser $NEWUSER
    echo "Make new user a sudoer?"
    echo -e "(Y/N):\c"
    read SUDO
    if [[ $SUDO == 'y' || $SUDO == 'Y' ]]; then
        sudo usermod -aG wheel $NEWUSER
    fi
fi


# First update and basic packages
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
sudo -u root sh -c 'cd $HOME;sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
# Some tweaks on theme
sudo sed -i "s|ZSH_THEME.*|ZSH_THEME=\"agnoster\"|g" /root/.zshrc
sudo sed -i "s|prompt_segment blue \$CURRENT_FG '%~'|prompt_segment blue \$CURRENT_FG '%1~'|g" /root/.oh-my-zsh/themes/agnoster.zsh-theme
sudo chsh -s /bin/zsh root

echo $SEP
sudo -u $NEWUSER sh -c 'cd $HOME;sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
# Some tweaks on theme
sudo sed -i "s|ZSH_THEME.*|ZSH_THEME=\"agnoster\"|g" /home/$NEWUSER/.zshrc
sudo sed -i "s|prompt_segment blue \$CURRENT_FG '%~'|prompt_segment blue \$CURRENT_FG '%1~'|g" /home/$NEWUSER/.oh-my-zsh/themes/agnoster.zsh-theme
sudo chsh -s /bin/zsh $NEWUSER


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

if [[ $DESK == 1 ]]; then
    echo $SEP
    git clone https://github.com/powerline/fonts.git --depth=1
    fonts/install.sh
    rm -rf fonts
fi

if [[ $MAIL == 1 ]]; then
    echo $SEP
    curl -LO https://github.com/roundcube/roundcubemail/releases/download/$ROUNDCUBE_VERSION/roundcubemail-$ROUNDCUBE_VERSION-complete.tar.gz
fi


# Configuration
if [[ $WEB == 1 || $MAIL == 1 ]]; then
    # User
    echo $SEP
    sudo adduser deploy
    sudo usermod -aG nginx deploy
    sudo usermod -aG nginx $NEWUSER

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
    mkdir templates
    sh -c 'cd templates;curl -LO https://raw.githubusercontent.com/qian2501/scripts/master/templates/nginx-main.conf'
    sh -c 'cd templates;curl -LO https://raw.githubusercontent.com/qian2501/scripts/master/templates/nginx-server.conf'
    sudo cp templates/nginx-main.conf /etc/nginx/nginx.conf

    if [[ $WEB == 1 ]]; then
        cp templates/nginx-server.conf templates/temp.conf
        if [[ ! -z $DOMAIN ]]; then
            sed -i "s|server_name _|server_name www.$DOMAIN|g" templates/temp.conf
        fi
        sed -i "s|root /path/to/site|root /home/site/path|g" templates/temp.conf

        echo -e "\n" | sudo tee -a /etc/nginx/nginx.conf > /dev/null
        cat templates/temp.conf | sudo tee -a /etc/nginx/nginx.conf > /dev/null
        rm -f templates/temp.conf
    fi

    if [[ $MAIL == 1 ]]; then
        cp templates/nginx-server.conf templates/temp.conf
        if [[ ! -z $DOMAIN ]]; then
            sed -i "s|server_name _|server_name mail.$DOMAIN|g" templates/temp.conf
        fi
        sed -i "s|root /path/to/site|root /home/site/roundcubemail|g" templates/temp.conf

        echo -e "\n" | sudo tee -a /etc/nginx/nginx.conf > /dev/null
        cat templates/temp.conf | sudo tee -a /etc/nginx/nginx.conf > /dev/null
        rm -f templates/temp.conf
    fi

    echo -e "}\n" | sudo tee -a /etc/nginx/nginx.conf > /dev/null
    rm -rf templates

    # PHP
    echo $SEP
    sudo sed -i "s|user = apache|user = nginx|g" /etc/php-fpm.d/www.conf
    sudo sed -i "s|group = apache|group = nginx|g" /etc/php-fpm.d/www.conf
    sudo sed -i "s|listen = /run/php-fpm/www.sock|listen = 127.0.0.1:9000|g" /etc/php-fpm.d/www.conf
    sudo sed -i "s|;listen.owner = nobody|listen.owner = nginx|g" /etc/php-fpm.d/www.conf
    sudo sed -i "s|;listen.group = nobody|listen.group = nginx|g" /etc/php-fpm.d/www.conf
    sudo sed -i "s|;listen.mode = 0660|listen.mode = 0660|g" /etc/php-fpm.d/www.conf
    sudo sed -i "s|listen.acl_users = apache,nginx|;listen.acl_users = apache,nginx|g" /etc/php-fpm.d/www.conf

    # PostgreSQL
    echo $SEP
    sudo postgresql-setup --initdb
    sudo sed -i "s|host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            md5|g" /var/lib/pgsql/data/pg_hba.conf

    if [[ $WEB == 1 ]]; then
        echo $SEP
        sudo systemctl start postgresql
        sudo -Hiu postgres createuser -P $DB_USER
        sudo -Hiu postgres createdb -O $DB_USER -E UNICODE $DB_NAME
        sudo systemctl stop postgresql
    fi

    if [[ $MAIL == 1 ]]; then
        echo $SEP
        sudo systemctl start postgresql
        sudo -Hiu postgres createuser -P roundcube
        sudo -Hiu postgres createdb -O roundcube -E UNICODE roundcubemail
        sudo systemctl stop postgresql
        sudo sed -i "s|mysql://roundcube:pass@localhost/roundcubemail|pgsql://roundcube:pass@127.0.0.1/roundcubemail|g" /home/site/roundcubemail/config/config.inc.php

        echo "!!! Please replace your password for Roundcube DB and run \"bin/initdb.sh --dir=SQL\" after script finished !!!"
    fi

    if [[ $MAIL == 1 ]]; then
        # Postfix
        echo $SEP
        sudo sed -i "s|#myhostname = virtual.domain.tld|myhostname = mail.$DOMAIN|g" /etc/postfix/main.cf
        sudo sed -i "s|#mydomain = domain.tld|mydomain = $DOMAIN|g" /etc/postfix/main.cf
        sudo sed -i "s|#myorigin = \$mydomain|myorigin = \$mydomain|g" /etc/postfix/main.cf
        sudo sed -i "s|^mydestination = \$myhostname, localhost.\$mydomain, localhost|#mydestination = \$myhostname, localhost.\$mydomain, localhost|g" /etc/postfix/main.cf
        sudo sed -i "s|#mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain$|mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain|g" /etc/postfix/main.cf

        # Dovecot
        sudo sed -i "s|#protocols = imap pop3 lmtp submission|protocols = imap pop3 lmtp|g" /etc/dovecot/dovecot.conf
        sudo sed -i "s|#listen = \*, ::|listen = \*, ::|g" /etc/dovecot/dovecot.conf

        # OpenDKIM
        # TODO

    fi
fi


# SSL
if [[ ($WEB == 1 || $MAIL == 1) && $DEV != 1 && DESK != 1 ]]; then
    # Nginx
    echo $SEP
    sudo certbot --nginx --non-interactive --agree-tos --domains www.$DOMAIN,mail.$DOMAIN --email $EMAIL_ADDRESS

    # Postfix
    echo "smtpd_use_tls = yes" | sudo tee -a /etc/postfix/main.cf
    sudo sed -i "s|smtpd_tls_cert_file = /etc/pki/tls/certs/postfix.pem|smtpd_tls_cert_file = /etc/letsencrypt/live/$DOMAIN/fullchain.pem|g" /etc/postfix/main.cf
    sudo sed -i "s|smtpd_tls_key_file = /etc/pki/tls/private/postfix.key|smtpd_tls_key_file = /etc/letsencrypt/live/$DOMAIN/privkey.pem|g" /etc/postfix/main.cf

    # Dovecot
    sudo sed -i "s|ssl_cert = </etc/pki/dovecot/certs/dovecot.pem|ssl_cert = </etc/letsencrypt/live/$DOMAIN/fullchain.pem|g" /etc/dovecot/conf.d/10-ssl.conf
    sudo sed -i "s|ssl_key = </etc/pki/dovecot/private/dovecot.pem|ssl_key = </etc/letsencrypt/live/$DOMAIN/privkey.pem|g" /etc/dovecot/conf.d/10-ssl.conf
fi

if [[ $DESK != 1 ]]; then
    sudo sed -i "s|Port 22|Port $SSH_PORT|g" /etc/ssh/sshd_config
fi


# Security
# SELinux
# TODO
echo $SEP
sudo setenforce 1
sudo setsebool -P httpd_can_network_connect 1

if [[ $MAIL == 1 ]]; then
    sudo chcon -Rt httpd_sys_content_t /home/site/roundcubemail
    sudo chcon -Rt httpd_sys_rw_content_t /home/site/roundcubemail/temp
    sudo chcon -Rt httpd_sys_rw_content_t /home/site/roundcubemail/logs
fi

if [[ $DESK != 1 ]]; then
    sudo semanage port -a -t ssh_port_t -p tcp $SSH_PORT
    echo "!!! If you don't want to use port 22 anymore, remember to delete it from SELinux !!!"
fi

# Firewalld
# TODO

# Fail2Ban
# TODO


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
    sudo systemctl enable --now dovecot
fi
