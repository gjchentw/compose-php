#!/usr/bin/with-contenv bash
set -e

# 建立 log 目錄
mkdir -p /var/log/cron
chown root:root /var/log/cron
chmod 755 /var/log/cron

# 確保 cron daemon 不會自己 background
sed -i 's/^\(.*-f.*\)$/# \1/' /etc/crontab || true
