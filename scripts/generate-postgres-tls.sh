#!/usr/bin/env bash
set -e

# ============================================================
# PostgreSQL 专用 TLS 证书生成脚本（含 *.svc.plus + 双 IP）
# 作者：SVC.PLUS PostgreSQL Server TLS Generator
# ============================================================

TLS_DIR="/etc/postgres-tls"
CA_DIR="$TLS_DIR/ca"
SERVER_DIR="$TLS_DIR/server"

echo ">>> [1/6] 创建目录结构 ..."
sudo mkdir -p "$CA_DIR" "$SERVER_DIR"
cd "$TLS_DIR"

# ============================================================
# 1. 创建私有 CA 根证书
# ============================================================
echo ">>> [2/6] 生成 PostgreSQL 专用私有 CA ..."
sudo openssl genrsa -aes256 -out "$CA_DIR/ca.key.pem" 4096
sudo chmod 600 "$CA_DIR/ca.key.pem"

sudo openssl req -x509 -new -nodes -key "$CA_DIR/ca.key.pem" -sha256 -days 3650 \
  -subj "/C=CN/O=SVC.PLUS PostgreSQL Authority/OU=DB Security/CN=SVC.PLUS PostgreSQL Root CA" \
  -out "$CA_DIR/ca.cert.pem"

# ============================================================
# 2. 生成服务器证书
# ============================================================
echo ">>> [3/6] 生成服务器私钥与 CSR ..."
sudo openssl genrsa -out "$SERVER_DIR/server.key.pem" 2048
sudo chmod 600 "$SERVER_DIR/server.key.pem"

sudo openssl req -new -key "$SERVER_DIR/server.key.pem" \
  -subj "/C=CN/O=SVC.PLUS PostgreSQL Server/OU=DB/CN=global-homepage.svc.plus" \
  -out "$SERVER_DIR/server.csr.pem"

# SAN 扩展配置
cat <<EOF | sudo tee "$SERVER_DIR/server.ext" >/dev/null
basicConstraints=CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.svc.plus
DNS.2 = svc.plus
DNS.3 = global-homepage.svc.plus
DNS.4 = cn-homepage.svc.plus
IP.1  = 167.179.72.223
IP.2  = 47.120.61.35
EOF

# 签发服务器证书（2年有效）
echo ">>> [4/6] 使用 SVC.PLUS PostgreSQL Root CA 签发服务器证书 ..."
sudo openssl x509 -req -in "$SERVER_DIR/server.csr.pem" \
  -CA "$CA_DIR/ca.cert.pem" -CAkey "$CA_DIR/ca.key.pem" \
  -CAcreateserial -out "$SERVER_DIR/server.cert.pem" \
  -days 730 -sha256 -extfile "$SERVER_DIR/server.ext"

# fullchain
sudo cat "$SERVER_DIR/server.cert.pem" "$CA_DIR/ca.cert.pem" | sudo tee "$SERVER_DIR/server.fullchain.pem" >/dev/null

# ============================================================
# 3. 安装到 PostgreSQL 标准路径
# ============================================================
echo ">>> [5/6] 安装证书到 PostgreSQL SSL 目录 ..."
sudo install -o postgres -g postgres -m 600 "$SERVER_DIR/server.key.pem" /etc/ssl/private/svc.plus-postgres.key
sudo install -o postgres -g postgres -m 644 "$SERVER_DIR/server.fullchain.pem" /etc/ssl/certs/svc.plus-postgres.crt
sudo install -o postgres -g postgres -m 644 "$CA_DIR/ca.cert.pem" /etc/ssl/certs/svc.plus-postgres-ca.crt

# ============================================================
# 4. 输出后续操作提示
# ============================================================
echo "==============================================================="
echo "✅ [SVC.PLUS PostgreSQL TLS] 已生成并安装完成"
echo ""
echo "请在 /etc/postgresql/16/main/postgresql.conf 中添加或确认以下配置："
echo ""
echo "  ssl = on"
echo "  ssl_cert_file = '/etc/ssl/certs/svc.plus-postgres.crt'"
echo "  ssl_key_file  = '/etc/ssl/private/svc.plus-postgres.key'"
echo "  ssl_ca_file   = '/etc/ssl/certs/svc.plus-postgres-ca.crt'"
echo ""
echo "⚙️  然后执行： sudo systemctl restart postgresql"
echo ""
echo "📦 客户端（订阅端）请复制 CA 根证书："
echo "  /etc/postgres-tls/ca/ca.cert.pem"
echo "至客户端路径："
echo "  /var/lib/postgresql/.postgresql/root.crt"
echo "（权限：600，属主 postgres）"
echo ""
echo "🔍 验证命令示例："
echo "  openssl s_client -connect 167.179.72.223:5432 -starttls postgres -servername global-homepage.svc.plus"
echo ""
echo "👑 证书主题：SVC.PLUS PostgreSQL Server"
echo "包含 SAN: *.svc.plus, global-homepage, cn-homepage, IP(167.179.72.223, 47.120.61.35)"
echo "==============================================================="

sudo chown postgres:postgres /etc/ssl/private/svc.plus-postgres.key
sudo chmod 600 /etc/ssl/private/svc.plus-postgres.key

sudo chown root:postgres /etc/ssl/private
sudo chmod 750 /etc/ssl/private


# 1️⃣ 创建目录
sudo -u postgres mkdir -p /var/lib/postgresql/.postgresql
# 2️⃣ 从 global-homepage 拉取服务器的 CA 根证书
sudo scp root@167.179.72.223:/etc/ssl/certs/svc.plus-postgres-ca.crt /var/lib/postgresql/.postgresql/root.crt
# 3️⃣ 设置权限
sudo chown postgres:postgres /var/lib/postgresql/.postgresql/root.crt
sudo chmod 600 /var/lib/postgresql/.postgresql/root.crt
