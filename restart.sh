#!/bin/bash
cd /root/vod
wget -O config.json.tmp https://raw.githubusercontent.com/LunaTechLab/MoonTV/refs/heads/main/config.json
if [ $? -eq 0 ]; then
    mv config.json.tmp config.json
    docker restart moontv-core
else
    echo "下载失败，配置文件未更新"
    rm -f config.json.tmp
fi
