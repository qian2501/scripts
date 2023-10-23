#!/bin/bash

usage() { 
    echo "Usage: $0 [-v <version>] [-M]";
    echo "-M            Major version upgrade";
    echo "-v <version>  Targeting specific version";
    echo "-h            Show help message";

    exit 1; 
}

while getopts "Mv:h" opt; do
    case "${opt}" in
        M)
            MAJOR=true
            ;;
        v)
            MANUAL=true
            NEWVER=${OPTARG}
            ;;
        h)
            usage
            ;;
    esac
done
shift $((OPTIND -1))

OS=$(awk -F'=' '/^ID=/ {print tolower($2)}' /etc/*-release)
OS=${OS#*\"}
OS=${OS%\"*}

if [[ $OS != "opensuse-leap" ]]; then
    echo "This script is for OpenSUSE Leap only!"
    exit 1
fi

VERSION=$(awk -F'=' '/^VERSION=/ {print $2}' /etc/*-release)
VERSION=${VERSION#*\"}
VERSION=${VERSION%\"*}
VERSION=(${VERSION//./ })

if [[ $MAJOR == true ]]; then
    NEWVER=$((${VERSION[0]} + 1)).0
elif [[ $MANUAL != true ]]; then
    NEWVER=${VERSION[0]}.$((${VERSION[1]} + 1))
fi

echo "Summary:"
echo "current version: ${VERSION[0]}.${VERSION[1]}"
echo "target version: $NEWVER"
echo -e "Confirm? (y/n):\c"
read CONFIRM
if [[ $CONFIRM != 'y' && $CONFIRM != 'Y' ]]; then
    exit 0
fi


sudo zypper refresh
sudo zypper update

sudo sed -i "s/${VERSION[0]}.${VERSION[1]}/\$releasever/g" /etc/zypp/repos.d/*.repo

sudo zypper --releasever=$NEWVER refresh
sudo zypper --releasever=$NEWVER dup --download-in-heaps
