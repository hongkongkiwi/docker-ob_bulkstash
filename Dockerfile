FROM alpine:3.8
MAINTAINER Thomas Spicer <thomas@openbridge.com>

ARG RCLONE_VERSION="current"
ARG SUPERCRONIC_VERSION="0.1.6"
ARG SUPERCRONIC_TYPE="amd64"

ENV RCLONE_TYPE="amd64"
ENV BUILD_DEPS \
      wget \
      linux-headers \
      unzip \
      fuse
RUN set -x \
    && apk update \
    && apk add --no-cache --virtual .persistent-deps \
       bash \
       curl \
       monit \
       ca-certificates \
    && apk add --no-cache --virtual .build-deps \
        $BUILD_DEPS \
    && cd /tmp  \
    && wget -q http://downloads.rclone.org/rclone-${RCLONE_VERSION}-linux-${RCLONE_TYPE}.zip \
    && unzip /tmp/rclone-${RCLONE_VERSION}-linux-${RCLONE_TYPE}.zip \
    && mv /tmp/rclone-*-linux-${RCLONE_TYPE}/rclone /usr/bin \
    && addgroup -g 1000 rclone \
    && adduser -SDH -u 1000 -s /bin/false rclone -G rclone \
    && sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf \
		&& wget -O "/usr/local/bin/supercronic" "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-${SUPERCRONIC_TYPE}" \
		&& chmod +x "/usr/local/bin/supercronic" \
	  && mkdir -p /config /defaults /data \
    && rm -Rf /tmp/* \
    && rm -rf /var/cache/apk/* \
    && apk del .build-deps

COPY monit.d/ /etc/monit.d/
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY rclone.sh /rclone.sh
COPY env_secrets.sh /env_secrets.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [""]
