FROM alpine:3.20

RUN apk add --no-cache \
    dovecot dovecot-lmtpd dovecot-pigeonhole-plugin \
    bash ca-certificates tzdata openssl

WORKDIR /dovecot

COPY config/ /etc/dovecot-tmpl/
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 993

ENTRYPOINT ["/entrypoint.sh"]
