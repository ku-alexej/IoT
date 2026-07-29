#!/usr/bin/env bash

set -euo pipefail

echo "=== VM CLEANUP START ==="
echo "[1/5] Cleaning /tmp and /var/tmp..."

rm -rf /tmp/* || true
rm -rf /var/tmp/* || true

echo "[2/5] Cleaning journal logs..."
journalctl --vacuum-time=7d || true

echo "[3/5] Cleaning package caches..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get clean
    apt-get autoremove -y
fi

if command -v dnf >/dev/null 2>&1; then
    dnf clean all
fi

if command -v pacman >/dev/null 2>&1; then
    pacman -Scc --noconfirm || true
fi

echo "[4/5] Cleaning user caches..."
for dir in /home/*; do
    if [ -d "$dir" ]; then
        USERNAME=$(basename "$dir")

        echo "  -> Cleaning user: $USERNAME"

        rm -rf "$dir/.cache/"* || true
        rm -rf "$dir/.local/share/Trash/"* || true

        rm -rf "$dir/.mozilla/firefox"/*/cache2 || true
        rm -rf "$dir/.config/google-chrome/Default/Cache" || true
        rm -rf "$dir/.config/chromium/Default/Cache" || true
    fi
done

echo "[5/5] Final sweep..."

find /tmp -type f -atime +10 -delete || true
find /var/tmp -type f -atime +10 -delete || true

echo "=== CLEANUP DONE ==="
df -h


rm -rf ~/.vagrant.d/boxes
rm -rf ~/.vagrant.d/tmp
rm -rf ~/.vagrant.d/rgloader
# rm -rf ~/.vagrant.d/boxes
rm -rf "~/VirtualBox VMs"
sudo rm -rf /var/lib/libvirt/images/*

du -xh /home --max-depth=2 2>/dev/null | sort -hr | head -30
