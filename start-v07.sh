
#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="$PROJECT_DIR/rootfs"

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Root yetkisi gerekli."
    exit 1
fi

if [[ ! -x "$ROOTFS/bin/bash" ]]; then
    echo "[!] Debian rootfs bulunamadi."
    exit 1
fi

if ! ip netns list | grep -qE '^mini-net([[:space:]]|$)'; then
    echo "[!] mini-net bulunamadi."
    exit 1
fi

echo "[+] Mini Container v0.7 baslatiliyor..."
echo "[+] RAM limiti: 256 MiB"
echo "[+] CPU kotasi: 100%"
echo "[+] Network: mini-net"

systemd-run --scope \
    --unit=mini-container-v07 \
    -p MemoryMax=256M \
    -p CPUQuota=100% \
    ip netns exec mini-net \
    unshare --fork --pid --uts --mount \
    --propagation private \
    --mount-proc="$ROOTFS/proc" \
    chroot "$ROOTFS" /bin/bash -e -c '

        hostname mini-container

        echo "[+] Sanal aygitlar hazirlaniyor..."

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

        echo "[+] Mini Container v0.7 hazir!"
        echo "[+] Hostname: $(hostname)"
        echo "[+] PID: $$"

        exec /bin/bash
    '
