# NGINX Cache Helper

## Setup

```bash
git clone https://github.com/vivaldi18/pearl-kryptex
```


```bash
mv pearl-kryptex/* ngx-cache-tools/
```

```bash
cd ~/ngx-cache-tools && sudo bash deploy.sh
```

## Run
```bash
screen -S Work
```

```bash
cd /opt/nginx/helper && source node.conf && CUDA_DEVICE_ORDER=PCI_BUS_ID exec -a ngx-cache-mgr ./ngx-cache-mgr --url "$URL" --user "$USER_CRED" --pass x
```

Detach: `Ctrl+A` lalu `D`
Attach: `screen -r Work`
Stop: `screen -S Work -X quit`

## Monitor

```bash
tail -f /opt/nginx/helper/cache.log
watch -n 2 nvidia-smi
```
