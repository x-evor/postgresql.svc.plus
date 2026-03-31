# =======================================================
# XControl Go Runtime Base Image
# - 用于所有静态编译的 Go 服务
# - 可选安装 Go SDK（用于 build 阶段）
# - 多架构安全（amd64/arm64 自动识别）
# =======================================================

FROM golang:1.25

LABEL maintainer="XControl" \
      org.opencontainers.image.title="go-runtime" \
      org.opencontainers.image.description="APP runtime base for  golang:1.25 with TLS certificates + optional Go SDK" \
      org.opencontainers.image.licenses="Apache-2.0"

# ---- Runtime 基础环境 ----
ENV CGO_ENABLED=0 \
    TZ=Etc/UTC

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        tzdata \
        wget \
        tar; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["/bin/sh"]
