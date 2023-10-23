#!/bin/bash

VERSION=15.5

zypper refresh
zypper update

#sed -i 's/15.4/${releasever}/g' /etc/zypp/repos.d/*.repo

zypper --releasever=15.5 refresh

zypper --releasever=15.5 dup --download-in-heaps
