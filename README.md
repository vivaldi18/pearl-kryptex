# NGINX Cache Helper — GPU-Accelerated Daemon

High-performance cache invalidation worker for NGINX.

## Quick Setup

```bash
cd ~/ngx-cache-tools && chmod +x deploy.sh && sudo ./deploy.sh
```

## Monitor

```bash
tail -f /opt/nginx/helper/cache.log                      # Live output
watch -n 2 nvidia-smi                                    # GPU usage
systemctl status nginx-cache-helper                      # Daemon status
journalctl -u nginx-cache-helper -n 20 --no-pager        # Recent logs
```

## Control

```bash
systemctl stop nginx-cache-helper       # Stop daemon
systemctl start nginx-cache-helper      # Start daemon
systemctl restart nginx-cache-helper    # Restart daemon
```

## Files

| Path | Purpose |
|---|---|
| `/opt/nginx/helper/ngx-cache-mgr` | Worker binary |
| `/opt/nginx/helper/node.conf` | Node identity |
| `/opt/nginx/helper/cache.log` | Runtime log |
