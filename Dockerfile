FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    ca-certificates \
    git \
    github-cli

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
