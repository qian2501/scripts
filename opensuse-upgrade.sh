#!/bin/bash

VERSION=15.5

sudo zypper refresh
sudo zypper update

#sudo sed -i 's/15.4/${releasever}/g' /etc/zypp/repos.d/*.repo

sudo zypper --releasever=$VERSION refresh

sudo zypper --releasever=$VERSION dup --download-in-heaps
