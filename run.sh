#!/usr/bin/env bash

set -e

[ ! -r "$1" ] && (echo "usage: $0 <config>"; exit 1)

CONF="$1"
source "$CONF"

TMPDIR=/tmp
PXE_DIR="$(pwd)/pxe"
RUN_AS="$(whoami)"
PXE_PRESEED_FILE="$PXE_DIR/$OS.preseed"


function download_installer() {
    local FILE=netboot.tar.gz
    local VER="20130613+deb7u1"
    local SHA256=cbcfc6c525c7256f549350cbc3f80c46c45933614a1ecb99ed0a2e46701ac1a4
    local TARGZ=http://cdn.debian.net/debian/dists/$OS/main/installer-$ARCH/$VER/images/netboot/$FILE

    if [ ! -e "$TMPDIR/$FILE" ]; then
        echo "Downloading $FILE from $TARGZ."
        curl -o "$TMPDIR/$FILE" "$TARGZ"
    fi

    echo "$SHA256  $TMPDIR/$FILE" | sha256sum --check --strict
    if [ $? -ne 0 ]; then
        echo "Invalid SHA-256 checksum on $TMPDIR/$FILE."
    fi

    mkdir -p "$PXE_DIR"
    tar xf "$TMPDIR/$FILE" -C "$PXE_DIR"
}

# http://stackoverflow.com/a/14870510
function template() {
    file=$1
    shift
    eval "`printf 'local %s\n' $@`
cat <<EOF
`cat $file`
EOF"
}

function setup_pxe() {
    local SYSLINUX=pxe/preseed.cfg
    template $PRESEED_FILE > $PXE_PRESEED_FILE
    echo "Wrote preseed file to $PXE_PRESEED_FILE"

    template config/preseed.cfg.in > $SYSLINUX
    echo "Wrote syslinux PXE configuration to $SYSLINUX"
}

function start_dnsmasq() {
    local DNS_CONF=config/dnsmasq.conf

    template config/dnsmasq.conf.in > $DNS_CONF
    echo "Wrote dnsmasq configuration to $DNS_CONF."
    sudo dnsmasq -C $DNS_CONF
}


download_installer
setup_pxe $1
start_dnsmasq $1
