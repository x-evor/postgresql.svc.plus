# 云平台部署

本项目不依赖特定云厂商，可在任意支持 Docker/Kubernetes 的平台上运行。

## VM 部署

- 适用：AWS EC2 / GCP Compute Engine / Azure VM / 阿里云等
- 开放端口：80/443（证书签发 + TLS 连接）
- 建议挂载独立数据盘（对应 `PG_DATA_PATH`）

## Kubernetes 部署

- 适用：EKS / GKE / AKS / K3s / K8s
- 使用 Helm Chart 管理配置与持久化
- 证书可通过 Secret 注入 stunnel sidecar
