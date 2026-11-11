#!/bin/bash
# Depot OS — thử gói thay thế cho trixie (chạy trong WSL Debian)
set -u
for p in "$@"; do
    if apt-get install --dry-run -y "$p" >/dev/null 2>&1; then
        echo "$p: OK"
    else
        echo "$p: KHONG_CO"
    fi
done
