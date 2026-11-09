#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="$PROJECT_DIR/rootfs"

NETNS="mini-net-v08"
VETH_HOST="veth08-host"
VETH_CONT="veth08-mini"

HOST_IP="10.202.88.1/24"
CONT_IP="10.202.88.2/24"
SUBNET="10.202.88.0/24"

NAT_TABLE="mini_container_v08"
SCOPE="mini-container-v08"

NET_CREATED=0
NAT_CREATED=0
FORWARD_CHANGED=0
OLD_FORWARD=""

# Root kontrolu
if [[ $(id -u) -ne 0 ]]; then
    echo "[!] sudo ile calistir."
    exit 1
fi

if [[ ! -x "$ROOTFS/bin/bash" ]]; then
    echo "[!] Debian rootfs bulunamadi."
    exit 1
fi

# Gerekli araclari kontrol et
for cmd in ip nft sysctl unshare chroot systemd-run; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[!] Eksik komut: $cmd"
        exit 1
    fi
done

# Mevcut kaynaklarla cakismayi engelle
if ip netns list | grep -q "^${NETNS}[[:space:]]"; then
    echo "[!] $NETNS zaten mevcut."
    exit 1
fi

if ip link show "$VETH_HOST" >/dev/null 2>&1; then
    echo "[!] $VETH_HOST zaten mevcut."
    exit 1
fi

if nft list table ip "$NAT_TABLE" >/dev/null 2>&1; then
    echo "[!] NAT tablosu zaten mevcut."
    exit 1
fi

if [[ -n "$(ip -4 route show "$SUBNET")" ]]; then
    echo "[!] $SUBNET agi zaten kullaniliyor."
    exit 1
fi

# Yalnizca script'in olusturdugu kaynaklari temizle
cleanup() {
    echo
    echo "[+] v0.8 ag kaynaklari temizleniyor..."

    if [[ $NAT_CREATED -eq 1 ]]; then
        nft delete table ip "$NAT_TABLE" || true
    fi

    if [[ $NET_CREATED -eq 1 ]]; then
        ip netns del "$NETNS" || true
        ip link del "$VETH_HOST" 2>/dev/null || true
    fi

    if [[ $FORWARD_CHANGED -eq 1 ]]; then
        sysctl -w "net.ipv4.ip_forward=$OLD_FORWARD" \
            >/dev/null || true
    fi

    echo "[+] Temizlik tamamlandi."
}

trap cleanup EXIT

echo "[+] Mini Container v0.8 baslatiliyor..."

# Network Namespace
ip netns add "$NETNS"
NET_CREATED=1

# Virtual Ethernet
ip link add "$VETH_HOST" type veth \
    peer name "$VETH_CONT"

ip link set "$VETH_CONT" netns "$NETNS"

# Host tarafi
ip addr add "$HOST_IP" dev "$VETH_HOST"
ip link set "$VETH_HOST" up

# Container tarafi
ip netns exec "$NETNS" \
    ip addr add "$CONT_IP" dev "$VETH_CONT"

ip netns exec "$NETNS" \
    ip link set "$VETH_CONT" up

ip netns exec "$NETNS" ip link set lo up

ip netns exec "$NETNS" \
    ip route add default via 10.202.88.1

echo "[+] Network Namespace hazir."

# NAT
nft add table ip "$NAT_TABLE"
NAT_CREATED=1

nft "add chain ip $NAT_TABLE postrouting { type nat hook postrouting priority srcnat; policy accept; }"

nft add rule ip "$NAT_TABLE" postrouting \
    ip saddr "$SUBNET" oifname "eth0" masquerade

# IP forwarding (eski degeri sakla)
OLD_FORWARD="$(sysctl -n net.ipv4.ip_forward)"

if [[ "$OLD_FORWARD" != "1" ]]; then
    FORWARD_CHANGED=1
    sysctl -w net.ipv4.ip_forward=1 >/dev/null
fi

echo "[+] NAT ve routing hazir."
echo "[+] RAM: 256 MiB"
echo "[+] CPU: 100%"

# Container baslat
systemd-run --scope \
    --unit="$SCOPE" \
    -p MemoryMax=256M \
    -p CPUQuota=100% \
    ip netns exec "$NETNS" \
    unshare --fork --pid --uts --mount \
    --propagation private \
    --mount-proc="$ROOTFS/proc" \
    chroot "$ROOTFS" /bin/bash -e -c '

        hostname mini-container

        # Sanal aygitlar
        mount -t tmpfs -o mode=755,nosuid tmpfs /dev
        mkdir -p /dev/pts /dev/shm

        mount -t devpts devpts /dev/pts \
            -o newinstance,ptmxmode=0666,mode=0620

        ln -s pts/ptmx /dev/ptmx

        mknod -m 666 /dev/null c 1 3
        mknod -m 666 /dev/zero c 1 5
        mknod -m 666 /dev/random c 1 8
        mknod -m 666 /dev/urandom c 1 9
        mknod -m 666 /dev/tty c 5 0

        mount -t tmpfs -o mode=1777,nosuid,nodev \
            tmpfs /dev/shm

        echo "[+] Mini Container v0.8 HAZIR!"
        echo "[+] Hostname: $(hostname)"
        echo "[+] PID: $$"
        echo "[+] IP: 10.202.88.2"
        echo "[+] Cikmak icin: exit"

        exec /usr/bin/setpriv \
            --bounding-set=-sys_admin,-net_admin \
            --inh-caps=-all \
            --ambient-caps=-all \
            --no-new-privs \
            /bin/bash



  '
