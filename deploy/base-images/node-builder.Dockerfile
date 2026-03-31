FROM node:22-bookworm

LABEL maintainer="XControl" \
      description="Node.js 22 builder image with Yarn and Next.js tooling"

ENV NEXT_TELEMETRY_DISABLED=1 \
    NODE_ENV=development

RUN set -eux; \
    corepack enable; \
    corepack prepare yarn@stable --activate; \
    npm install -g npm@latest; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        python3 \
        ca-certificates; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["bash"]
