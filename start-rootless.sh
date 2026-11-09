
#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="$PROJECT_DIR/rootfs-rootless"

if [[ $(id -u) -eq 0 ]]; then
    echo "[!] Bu script sudo kullanilmadan calistirilmali."
    exit 1
fi

if [[ ! -x "$ROOTFS/bin/bash" ]]; then
    echo "[!] Debian rootfs bulunamadi."
    exit 1
fi

echo "[+] Rootless Mini Container baslatiliyor..."

unshare \
    --user --map-root-user \
    --mount --pid --uts --fork \
    --mount-proc="$ROOTFS/proc" \
    --propagation private \
    chroot "$ROOTFS" /bin/bash -c '
        hostname mini-rootless

        echo "[+] Rootless Container hazir!"
        echo "[+] Hostname: $(hostname)"
        echo "[+] PID: $$"
        echo "[+] UID: $(id -u)"

        exec /bin/bash
    '
