#!/bin/bash
# Should execute WITH sudo

# Var
SEP=----------
NGINX_VERSION="nginx-1.21.0"
NGINX_RTMP_MODULE_VERSION="1.2.2"

# Get distro name
OS=$(awk -F'=' '/^ID=/ {print tolower($2)}' /etc/*-release)
# For CentOS the name will contain d-quotes, which need to be removed
OS=${OS#*\"}
OS=${OS%\"*}

# Get package manager from distro
# Leave a space at the end for expansion
if [ $OS = "ubuntu" ]||[ $OS = "debian" ]; then
    PM=apt
    PKGS="gcc make ca-certificates openssl libssl-dev libpcre3-dev "
    UNITFILE_PATH=""
elif [ $OS = "centos" ]||[ $OS = "rhel" ]; then
    PM=yum
    PKGS="gcc make ca-certificates openssl openssl-devel pcre-devel "
    UNITFILE_PATH=""
elif [ $OS = "opensuse-leap" ] then
    PM=zypper
    PKGS="gcc make ca-certificates openssl openssl-devel pcre-devel "
    UNITFILE_PATH="/usr/lib/systemd/system"
fi

# Install required packages
echo $SEP
$PM update
$PM install -y $PKGS

# Download and decompress Nginx
echo $SEP
mkdir -p /tmp/build/nginx
cd /tmp/build/nginx
if [ ! -d /tmp/build/nginx/$NGINX_VERSION ]; then
    wget -O $NGINX_VERSION.tar.gz https://nginx.org/download/$NGINX_VERSION.tar.gz
    tar -xzf $NGINX_VERSION.tar.gz
fi

# Download and decompress RTMP module
echo $SEP
mkdir -p /tmp/build/nginx-rtmp-module
cd /tmp/build/nginx-rtmp-module
if [ ! -d /tmp/build/nginx-rtmp-module/nginx-rtmp-module-$NGINX_RTMP_MODULE_VERSION ]; then
    wget -O nginx-rtmp-module-$NGINX_RTMP_MODULE_VERSION.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v$NGINX_RTMP_MODULE_VERSION.tar.gz
    tar -zxf nginx-rtmp-module-$NGINX_RTMP_MODULE_VERSION.tar.gz
fi

# In case source download failed
if [ ! -d /tmp/build/nginx/$NGINX_VERSION ]||[ ! -d /tmp/build/nginx-rtmp-module/nginx-rtmp-module-$NGINX_RTMP_MODULE_VERSION ]; then
    exit 0
fi

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change explicitly.
# Not just for order but to have it in the PATH
echo $SEP
if [ ! -d /etc/nginx ]; then
    mkdir /etc/nginx
fi
cd /tmp/build/nginx/$NGINX_VERSION
./configure \
    --sbin-path=/sbin \
    --conf-path=/etc/nginx/nginx.conf \
    --http-log-path=/var/log/nginx/access.log \
    --error-log-path=/var/log/nginx/error.log \
    --pid-path=/var/run/nginx/nginx.pid \
    --lock-path=/var/lock/nginx/nginx.lock \
    --http-client-body-temp-path=/tmp/nginx-client-body \
    --with-http_ssl_module \
    --with-threads \
    --with-ipv6 \
    --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-$NGINX_RTMP_MODULE_VERSION
if [ -d /var/lock/nginx ]; then
    mkdir /var/lock/nginx
fi

# Make
echo $SEP
make
make install

# Clean up
echo $SEP
rm -rf /tmp/build

# Create unitfile
touch $UNITFILE_PATH/nginx.service
echo "[Unit]
Description=The nginx HTTP and reverse proxy server
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=idle
PIDFile=/var/run/nginx/nginx.pid
ExecStartPre=/usr/bin/rm -rf /var/run/nginx
ExecStartPre=/usr/bin/mkdir /var/run/nginx
ExecStartPre=/usr/bin/touch /var/run/nginx/nginx.pid
ExecStartPre=/sbin/nginx -t
ExecStart=/sbin/nginx -g \"daemon off;\"
ExecReload=/bin/kill -s HUP \$MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target" > $UNITFILE_PATH/nginx.service
