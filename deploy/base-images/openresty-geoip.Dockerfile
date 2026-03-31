FROM openresty/openresty:1.27.1.2-5-bookworm

LABEL maintainer="XControl" \
      description="OpenResty base image with GeoIP2 libraries and lua-resty-maxminddb"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates libmaxminddb0 libmaxminddb-dev mmdb-bin luarocks; \
    apt-get install -y --only-upgrade libpam-modules libpam-modules-bin libpam-runtime libpam0g zlib1g; \
    apt-get purge -y --auto-remove git luarocks; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# OpenResty 配置（nginx.conf, conf.d/*.conf, lua/）
VOLUME ["/etc/openresty/conf"]

# GeoIP 数据目录（mmdb 文件）
VOLUME ["/usr/local/openresty/geoip"]


CMD ["nginx", "-g", "daemon off;"]
