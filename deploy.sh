#!/bin/bash

# 配置变量
CONTAINER_NAME="moontv"
IMAGE_NAME="ghcr.io/lunatechlab/moontv:latest"
LOCAL_PORT=3000
CONTAINER_PORT=3000
HOST_APP_DIR="./moontv_app_data"

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

# 创建宿主机挂载目录
echo "创建宿主机挂载目录: $HOST_APP_DIR"
mkdir -p "$HOST_APP_DIR"

# 检查宿主机目录是否为空，如果为空则从容器复制文件
if [ -z "$(ls -A "$HOST_APP_DIR")" ]; then
    echo "宿主机目录为空，准备从容器复制文件..."
    
    # 先临时运行一个容器来复制文件
    TEMP_CONTAINER="moontv_temp_$(date +%s)"
    echo "启动临时容器以复制文件..."
    
    if docker run -d --name $TEMP_CONTAINER $IMAGE_NAME sleep 10; then
        # 等待容器启动
        sleep 2
        
        # 复制容器内/app目录到宿主机
        echo "正在复制容器内文件到宿主机..."
        if docker cp $TEMP_CONTAINER:/app/. "$HOST_APP_DIR"; then
            echo "文件复制完成"
        else
            echo "警告: 文件复制失败"
        fi
        
        # 停止并删除临时容器
        docker stop $TEMP_CONTAINER >/dev/null 2>&1
        docker rm $TEMP_CONTAINER >/dev/null 2>&1
    else
        echo "警告: 无法启动临时容器来复制文件"
    fi
fi

# 设置目录权限，确保容器可以读写
echo "设置目录权限..."
chmod -R 777 "$HOST_APP_DIR"

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
        
        if ! docker run -d \
            --name $CONTAINER_NAME \
            -p $LOCAL_PORT:$CONTAINER_PORT \
            --env PASSWORD=$password \
            -v "$HOST_APP_DIR":/app \
            --user $(id -u):$(id -g) \
            $IMAGE_NAME; then
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
    
    if ! docker run -d \
        --name $CONTAINER_NAME \
        -p $LOCAL_PORT:$CONTAINER_PORT \
        --env PASSWORD=$password \
        -v "$HOST_APP_DIR":/app \
        --user $(id -u):$(id -g) \
        $IMAGE_NAME; then
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
echo "挂载目录: $HOST_APP_DIR -> /app"

# 显示容器状态
echo
echo "=== 容器状态 ==="
docker ps -f name=^${CONTAINER_NAME}$ --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "部署完成!"
echo "注意: 如果仍然出现权限问题，请手动运行以下命令:"
echo "chmod -R 777 $HOST_APP_DIR"
