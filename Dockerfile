FROM tiredofit/alpine:3.12 as kapi-builder

ARG KAPI_REPO_URL
ARG KAPI_VERSION

ENV KAPI_REPO_URL=${KAPI_REPO_URL:-"https://github.com/Kopano-dev/kapi"} \
    KAPI_VERSION=${KAPI_VERSION:-"v0.15.1"}

#ADD build-assets/kopano-kapi /build-assets

RUN set -x && \
    apk update && \
    apk upgrade && \
    apk add -t .kapi-build-deps \
                build-base \
                coreutils \
                gettext \
                git \
                go \
                tar \
                && \
    \
    git clone ${KAPI_REPO_URL} /usr/src/kapi && \
    cd /usr/src/kapi && \
    git checkout ${KAPI_VERSION} && \
    \
    if [ -d "/build-assets/src/kapi" ] ; then cp -R /build-assets/src/kapi/* /usr/src/kapi ; fi; \
    if [ -f "/build-assets/scripts/kapi.sh" ] ; then /build-assets/scripts/kapi.sh ; fi; \
    \
    make && \
    mkdir -p /rootfs/usr/libexec/kopano/ && \
    cp -R ./bin/* /rootfs/usr/libexec/kopano/ && \
    mkdir -p /rootfs/tiredofit && \
    echo "KAPI ${KAPI_VERSION} built from  ${KAPI_REPO_URL} on $(date)" > /rootfs/tiredofit/kapi.version && \
    echo "Commit: $(cd /usr/src/kapi ; echo $(git rev-parse HEAD))" >> /rootfs/tiredofit/kapi.version && \
    cd /rootfs && \
    tar cvfz /kopano-kapi.tar.gz . && \
    cd / && \
    apk del .kapi-build-deps && \
    rm -rf /usr/src/* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /rootfs

FROM tiredofit/alpine:3.12
LABEL maintainer="Dave Conroy (dave at tiredofit dot ca)"

ENV ENABLE_SMTP=FALSE \
    ZABBIX_HOSTNAME=kapi-app

### Move Previously built files from builder image
COPY --from=kapi-builder /*.tar.gz /usr/src/kapi/

RUN set -x && \
    apk update && \
    apk upgrade && \
    apk add -t .kapi-run-deps \
                mariadb-client \
                openssl \
                sqlite \
                && \
    \
    ##### Unpack KAPI
    tar xvfz /usr/src/kapi/kopano-kapi.tar.gz -C / && \
    rm -rf /usr/src/* && \
    rm -rf /etc/kopano && \
    ln -sf /config /etc/kopano && \
    rm -rf /var/cache/apk/*

ADD install /
