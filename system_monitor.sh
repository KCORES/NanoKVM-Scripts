#!/bin/bash

# 定义要监控的网络接口数组
INTERFACES=("eth0" "usb0" "wlan0" "tailscale0")

# 默认不使用颜色
USE_COLOR=0

# 解析命令行参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --color) USE_COLOR=1 ;;
        -h|--help)
            echo "Usage: $0 [--color]"
            echo "  --color    启用彩色输出"
            exit 0
            ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
    shift
done

# 颜色定义
if [ $USE_COLOR -eq 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# 获取系统负载
get_load() {
    cat /proc/loadavg | awk '{print $1, $2, $3}'
}

# 获取内存使用情况
get_memory() {
    free -m | awk 'NR==2{printf "%.2f%%\t\t%d/%dMB\n", $3*100/$2, $3, $2 }'
}

# 获取磁盘使用情况
get_disk_usage() {
    echo "根目录 (/):"
    df -h | awk '$NF=="/" {printf "\t%s/%s (%s)\n", $3, $2, $5}'
    
    echo "启动分区 (/boot):"
    df -h | awk '$NF=="/boot" {printf "\t%s/%s (%s)\n", $3, $2, $5}'
    
    echo "数据分区 (/data):"
    df -h | awk '$NF=="/data" {printf "\t%s/%s (%s)\n", $3, $2, $5}'
}

# 获取指定接口的网络使用情况
get_network_interface() {
    local interface=$1
    # 检查接口是否存在
    if [ -e "/sys/class/net/$interface" ]; then
        # 获取初始值
        RX1=$(cat /sys/class/net/$interface/statistics/rx_bytes)
        TX1=$(cat /sys/class/net/$interface/statistics/tx_bytes)
        sleep 1
        # 一秒后再次获取值
        RX2=$(cat /sys/class/net/$interface/statistics/rx_bytes)
        TX2=$(cat /sys/class/net/$interface/statistics/tx_bytes)
        
        # 计算速率
        RX_RATE=$(( ($RX2 - $RX1) / 1024 ))
        TX_RATE=$(( ($TX2 - $TX1) / 1024 ))
        
        # 获取接口状态
        if [ -e "/sys/class/net/$interface/operstate" ]; then
            STATUS=$(cat /sys/class/net/$interface/operstate)
        else
            STATUS="unknown"
        fi
        
        echo -e "${BLUE}$interface${NC} [$STATUS] RX: ${RX_RATE}KB/s TX: ${TX_RATE}KB/s"
    else
        echo -e "${BLUE}$interface${NC} [不存在]"
    fi
}

# 清屏
clear

echo -e "${GREEN}=== 系统监控信息 ===${NC}"
echo -e "${YELLOW}负载情况 (1分钟 5分钟 15分钟)：${NC}"
get_load

echo -e "\n${YELLOW}内存使用情况：${NC}"
echo -e "使用率\t\t已用/总量"
get_memory

echo -e "\n${YELLOW}磁盘使用情况：${NC}"
get_disk_usage

echo -e "\n${YELLOW}网络使用情况：${NC}"
# 获取所有接口的初始数据
declare -A RX1_ALL
declare -A TX1_ALL
for interface in "${INTERFACES[@]}"; do
    if [ -e "/sys/class/net/$interface" ]; then
        RX1_ALL[$interface]=$(cat /sys/class/net/$interface/statistics/rx_bytes)
        TX1_ALL[$interface]=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    fi
done

sleep 1

# 显示所有接口的网络使用情况
for interface in "${INTERFACES[@]}"; do
    get_network_interface "$interface"
done
