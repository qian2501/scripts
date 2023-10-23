#!/bin/bash

VERSION=15.5

sudo zypper refresh
sudo zypper update

#sudo sed -i 's/15.4/${releasever}/g' /etc/zypp/repos.d/*.repo

sudo zypper --releasever=15.5 refresh

sudo zypper --releasever=15.5 dup --download-in-heaps
