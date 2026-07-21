#!/bin/bash

MARKER=".polaris_mode"

case "$1" in
    --off)
        rm -rf "$MARKER"
        echo "[+] Polaris build mode DISABLED"
        echo "[+] Run: ./build.sh -t sdm845 (mainline)"
        ;;
    *)
        mkdir -p "$MARKER"
        echo "[+] Polaris build mode ENABLED"
        echo "[+] Run: ./build.sh -t sdm845"
        echo "[+] To disable: ./set-build-polaris.sh --off"
        ;;
esac