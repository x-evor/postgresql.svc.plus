FROM node:22-slim

LABEL maintainer="XControl" \
      description="Slim Node.js 22 runtime for production Next.js deployments"

ENV NEXT_TELEMETRY_DISABLED=1 \
    NODE_ENV=production

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    corepack enable

WORKDIR /app

CMD ["node"]
