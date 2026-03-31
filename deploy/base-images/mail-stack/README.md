# Mail Stack – Chasquid + Dovecot + Certbot (Split Containers)

架构图
```
                INBOUND EMAIL
                ↓ 25 (SMTP)
                +-----------+
INTERNET →→→→→ | chasquid  | →→→ outbound relay (optional)
                +-----------+
       ↑ 587 (STARTTLS) | 465 (TLS)
       |                 |
CLIENTS -----------------+
       \----→ dovecot →→ IMAP 993 / POP SSL 995
               ↑
        chasquid → dovecot-auth → 用户认证
```

# Mail Stack: Chasquid + Dovecot + Certbot

This stack provides:

- SMTP (25)
- Submission (587)
- SMTPS (465)
- IMAPS (993)

Certbot (TLS) and nginx (ACME validation) use **official images**.


Certbot (TLS) and nginx (ACME validation) use **official images**.

## Start

docker compose up -d

## Initialize user:

docker exec chasquid chasquid-util domain-add svc.plus
docker exec chasquid chasquid-util user-add admin@svc.plus
