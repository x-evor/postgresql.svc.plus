FROM alpine:3.20

RUN apk add --no-cache chasquid bash ca-certificates tzdata openssl shadow

WORKDIR /chasquid

COPY config/ /etc/chasquid-tmpl/
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 25 465 587

ENTRYPOINT ["/entrypoint.sh"]
