# CLI 与脚本

项目没有独立 CLI 工具，主要通过 Makefile 与脚本完成常见操作。

## Makefile 常用命令

```bash
make help
make init
make build-postgres-image
make test-postgres
make deploy-docker
make deploy-helm
make selftest
make clean
```

> `make deploy-docker` 在 Makefile 中标记为 legacy，建议优先使用 `make init` 或手动执行 Compose。

## 关键脚本

- `scripts/init_vhost.sh`：一键部署（构建镜像 + 证书 + stunnel 服务端）
- `deploy/docker/generate-certs.sh`：生成 stunnel 自签名证书
- `scripts/selftest.sh`：对 stunnel 客户端配置进行本地自检
