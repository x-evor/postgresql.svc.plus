# 代码结构

```
postgresql.svc.plus/
├── deploy/
│   ├── base-images/          # PostgreSQL 扩展镜像构建
│   ├── docker/               # Docker Compose 部署
│   └── helm/                 # Helm Chart
├── scripts/                  # 一键部署与自检脚本
├── example/                  # 示例配置
├── tests/                    # 测试相关资源
├── test-cases/               # 本地测试脚本与用例
└── docs/                     # 文档
```

关键目录说明：

- `deploy/docker/`：compose 文件、证书、stunnel 配置
- `deploy/helm/postgresql/`：chart 模板与默认 values
- `deploy/base-images/`：扩展镜像构建文件
