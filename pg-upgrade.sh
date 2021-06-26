#!/bin/bash
# Should execute WITH sudo

# Var
SEP=----------
OLDVER=12
NEWVER=13

# Get distro name
OS=$(awk -F'=' '/^ID=/ {print tolower($2)}' /etc/*-release)
# Some OS the name will contain d-quotes, which need to be removed
OS=${OS#*\"}
OS=${OS%\"*}

# Get package manager from distro
# Leave a space at the end for expansion
# OSs other than Leap will exit fail, due to untested
if [ $OS = "ubuntu" ]||[ $OS = "debian" ]; then
    PM=apt
    PKGS=""
    PG_UPGRADE=
    PG_BIN_OLD=""
    PG_DATA_OLD=""
    PG_CONF_OLD=""
    PG_BIN_NEW=""
    PG_DATA_NEW=""
    PG_CONF_NEW=""
    exit 1
elif [ $OS = "centos" ]||[ $OS = "rhel" ]; then
    PM=yum
    PKGS=""
    PG_UPGRADE=
    PG_BIN_OLD=""
    PG_DATA_OLD=""
    PG_CONF_OLD=""
    PG_BIN_NEW=""
    PG_DATA_NEW=""
    PG_CONF_NEW=""
    exit 1
elif [ $OS = "opensuse-leap" ]; then
    PM=zypper
    PKGS="postgresql$NEWVER-contrib"
    PG_UPGRADE=/usr/bin/pg_upgrade
    PG_BIN_OLD="/usr/lib/postgresql$OLDVER/bin"
    PG_DATA_OLD="/var/lib/pgsql/data.old"
    PG_CONF_OLD="/var/lib/pgsql/data.old/postgresql.conf"
    PG_BIN_NEW="/usr/lib/postgresql$NEWVER/bin"
    PG_DATA_NEW="/var/lib/pgsql/data"
    PG_CONF_NEW="/var/lib/pgsql/data/postgresql.conf"
else
    exit 1
fi

# Install required packages
echo $SEP
$PM update
$PM install -y $PKGS

# Stop Postgresql
echo $SEP
systemctl stop postgresql

# Rename old data
echo $SEP
sudo mv /var/lib/pgsql/data /var/lib/pgsql/data.old

# Start Postgresql once for new data folder
echo $SEP
systemctl start postgresql
systemctl stop postgresql

# Migrate
echo $SEP
sudo -Hiu postgres $PG_UPGRADE \
     --old-datadir=$PG_DATA_OLD \
     --new-datadir=$PG_DATA_NEW \
     --old-bindir=$PG_BIN_OLD \
     --new-bindir=$PG_BIN_NEW \
     --old-options "-c config_file=$PG_CONF_OLD" \
     --new-options "-c config_file=$PG_CONF_NEW"

cp $PG_DATA_OLD/pg_hba.conf $PG_DATA_NEW
