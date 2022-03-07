FROM alpine:3.15

RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories \
  && apk add --no-cache \
    bash \
    ca-certificates \
    git \
    hub

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
