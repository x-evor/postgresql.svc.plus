# 常见问题排查

## 1) 容器启动失败

```bash
docker-compose ps
docker-compose logs postgres
```

检查 `deploy/docker/.env` 中 `POSTGRES_PASSWORD` 是否为空（模板为 `deploy/docker/.env.example`）。

## 2) 无法连接数据库

- 确认 stunnel 服务端运行：`docker-compose logs stunnel`
- 确认端口放行（80/443 或自定义端口）
- 使用 `openssl s_client -connect host:port` 测试 TLS

## 3) 证书获取失败

- 域名是否解析到当前服务器
- 80 端口是否被占用
- 重试 `scripts/init_vhost.sh` 或手动生成证书

## 4) 扩展缺失

```bash
psql -U postgres -d postgres -c "\dx"
```

如扩展未安装，请检查初始化脚本与镜像版本。
