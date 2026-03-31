#!/bin/bash
# init-letsencrypt.sh
# 初始化 Let's Encrypt SSL 证书

set -e

# 配置
DOMAIN="${DOMAIN:-db.example.com}"
EMAIL="${EMAIL:-admin@example.com}"
STAGING="${STAGING:-0}"  # 设置为 1 使用 staging 环境测试

CERTBOT_CONF="./certbot_conf"
CERTBOT_WWW="./certbot_www"

echo "🔐 初始化 Let's Encrypt SSL 证书"
echo "=================================="
echo "域名: $DOMAIN"
echo "邮箱: $EMAIL"
echo "Staging: $STAGING"
echo ""

# 检查域名配置
if [ "$DOMAIN" = "db.example.com" ]; then
    echo "⚠️  警告: 请设置实际的域名!"
    echo "使用方法: DOMAIN=your-domain.com EMAIL=your@email.com ./init-letsencrypt.sh"
    exit 1
fi

# 创建必要的目录
mkdir -p "$CERTBOT_CONF/live/$DOMAIN"
mkdir -p "$CERTBOT_WWW"

# 检查是否已有证书
if [ -d "$CERTBOT_CONF/live/$DOMAIN" ] && [ -f "$CERTBOT_CONF/live/$DOMAIN/fullchain.pem" ]; then
    echo "✅ 证书已存在: $CERTBOT_CONF/live/$DOMAIN"
    read -p "是否重新生成证书? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 0
    fi
fi

# 创建临时自签名证书 (用于首次启动 Nginx)
echo "📝 创建临时自签名证书..."
openssl req -x509 -nodes -newkey rsa:4096 \
    -days 1 \
    -keyout "$CERTBOT_CONF/live/$DOMAIN/privkey.pem" \
    -out "$CERTBOT_CONF/live/$DOMAIN/fullchain.pem" \
    -subj "/CN=$DOMAIN" 2>/dev/null

echo "✅ 临时证书已创建"

# 启动 Nginx (使用临时证书)
echo "🚀 启动 Nginx..."
docker-compose -f docker-compose.yml -f docker-compose.nginx.yml up -d nginx

echo "⏳ 等待 Nginx 启动..."
sleep 5

# 删除临时证书
echo "🗑️  删除临时证书..."
docker-compose -f docker-compose.yml -f docker-compose.nginx.yml exec nginx rm -rf /etc/letsencrypt/live/$DOMAIN

# 请求 Let's Encrypt 证书
echo "📜 请求 Let's Encrypt 证书..."

STAGING_ARG=""
if [ "$STAGING" = "1" ]; then
    STAGING_ARG="--staging"
    echo "⚠️  使用 staging 环境 (测试模式)"
fi

docker-compose -f docker-compose.yml -f docker-compose.nginx.yml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    $STAGING_ARG \
    -d $DOMAIN

# 重新加载 Nginx
echo "🔄 重新加载 Nginx..."
docker-compose -f docker-compose.yml -f docker-compose.nginx.yml exec nginx nginx -s reload

echo ""
echo "✅ SSL 证书初始化完成!"
echo ""
echo "证书位置: $CERTBOT_CONF/live/$DOMAIN/"
echo "证书有效期: 90 天"
echo "自动续期: certbot 容器会每 12 小时检查一次"
echo ""
echo "测试 HTTPS 访问:"
echo "  curl https://$DOMAIN/health"
echo ""
echo "查看证书信息:"
echo "  docker-compose -f docker-compose.yml -f docker-compose.nginx.yml run --rm certbot certificates"
echo ""
echo "手动续期证书:"
echo "  docker-compose -f docker-compose.yml -f docker-compose.nginx.yml run --rm certbot renew"
