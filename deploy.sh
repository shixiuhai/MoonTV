#!/bin/bash

# 配置变量
CONTAINER_NAME="moontv"
IMAGE_NAME="ghcr.io/lunatechlab/moontv:latest"
LOCAL_PORT=3000
CONTAINER_PORT=3000

# 检查是否以root权限运行
if [ "$EUID" -eq 0 ]; then
    echo "警告: 不建议以root权限运行此脚本"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "=== MoonTV 部署脚本 ==="
echo

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "错误: Docker未安装"
    exit 1
fi

# 检查镜像是否存在
image_exists=$(docker images -q $IMAGE_NAME)

if [ ! -z "$image_exists" ]; then
    echo "发现本地镜像: $IMAGE_NAME"
    read -p "是否重新拉取镜像? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "正在拉取最新镜像..."
        if ! docker pull $IMAGE_NAME; then
            echo "错误: 镜像拉取失败"
            exit 1
        fi
        echo "镜像拉取完成"
    else
        echo "使用现有镜像"
    fi
else
    echo "未找到本地镜像，正在拉取..."
    if ! docker pull $IMAGE_NAME; then
        echo "错误: 镜像拉取失败"
        exit 1
    fi
    echo "镜像拉取完成"
fi

echo

# 检查容器是否存在
container_exists=$(docker ps -aq -f name=^${CONTAINER_NAME}$)

if [ ! -z "$container_exists" ]; then
    echo "发现现有容器: $CONTAINER_NAME"
    read -p "是否重建容器? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "正在停止容器..."
        docker stop $CONTAINER_NAME >/dev/null 2>&1
        
        echo "正在删除旧容器..."
        docker rm $CONTAINER_NAME >/dev/null 2>&1
        
        echo "正在创建新容器..."
        # 询问密码
        read -p "请输入访问密码 (默认: your_password): " password
        if [ -z "$password" ]; then
            password="your_password"
        fi
        
        if ! docker run -d --name $CONTAINER_NAME -p $LOCAL_PORT:$CONTAINER_PORT --env PASSWORD=$password $IMAGE_NAME; then
            echo "错误: 容器创建失败"
            exit 1
        fi
        
        echo "容器重建完成"
    else
        echo "保持现有容器运行"
        # 检查容器状态
        container_status=$(docker ps -q -f name=^${CONTAINER_NAME}$)
        if [ ! -z "$container_status" ]; then
            echo "容器状态: 运行中"
        else
            echo "容器状态: 已停止"
            read -p "是否启动容器? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if docker start $CONTAINER_NAME; then
                    echo "容器已启动"
                else
                    echo "错误: 容器启动失败"
                fi
            fi
        fi
    fi
else
    echo "未找到现有容器，正在创建新容器..."
    # 询问密码
    read -p "请输入访问密码 (默认: your_password): " password
    if [ -z "$password" ]; then
        password="your_password"
    fi
    
    if ! docker run -d --name $CONTAINER_NAME -p $LOCAL_PORT:$CONTAINER_PORT --env PASSWORD=$password $IMAGE_NAME; then
        echo "错误: 容器创建失败"
        exit 1
    fi
    
    echo "容器创建完成"
fi

echo
echo "=== 部署信息 ==="
echo "容器名称: $CONTAINER_NAME"
echo "访问地址: http://localhost:$LOCAL_PORT"
echo "镜像版本: $IMAGE_NAME"

# 显示容器状态
echo
echo "=== 容器状态 ==="
docker ps -f name=^${CONTAINER_NAME}$ --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "部署完成!"
