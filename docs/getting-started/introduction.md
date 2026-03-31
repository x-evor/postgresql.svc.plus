# 项目介绍

PostgreSQL Service Plus 是一个“生产就绪的 PostgreSQL 运行时”，内置常用扩展（向量检索、中文分词、消息队列等），并提供多种安全部署模式（Docker Compose、Kubernetes/Helm、TLS 隧道）。

## 解决的问题

- 用一个 PostgreSQL 实例覆盖多类数据能力（向量检索、全文搜索、消息队列、文档存储）。
- 在不改应用代码的前提下，通过 stunnel 提供 TLS 加密的数据库入口。
- 以可复制的方式在 VM 或 K8s 环境中部署，避免手工安装扩展。

## 适用场景

- 需要快速搭建“多模型数据库”的团队或个人项目。
- 需要在公网/跨机房连接数据库，但希望“应用侧保持普通 PostgreSQL 连接”。
- 希望统一扩展版本并可持续升级的生产环境。

## 核心能力一览

- PostgreSQL 运行时镜像（预装扩展）。
- Docker Compose 与 Helm Chart 部署模板。
- stunnel TLS 隧道（默认使用 443 对外暴露，数据库仅内部监听）。
- 可选 Caddy 或 Nginx+Certbot 的证书管理/健康检查。
