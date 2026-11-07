FROM docker.io/ubuntu:22.04 AS base

WORKDIR /archi

ARG TZ=UTC

# hadolint ignore=DL3008
RUN set -eux; \
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime; \
    echo "$TZ" > /etc/timezone; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      language-pack-en-base \
      at-spi2-core \
      libgtk2.0-0 \
      libswt-gtk-4-jni \
      libxext6 \
      libxrender1 \
      libxi6 \
      libxtst6 \
      libglib2.0-0 \
      libcairo2 \
      libpango-1.0-0 \
      libpangocairo-1.0-0 \
      dbus \
      dbus-x11 \
      xvfb \
      curl \
      git \
      openssh-client \
      unzip; \
    apt-get clean; \
    update-ca-certificates; \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

FROM base AS archi
ARG ARCHI_VERSION=5.10.0
ARG ARCHI_RELEASE_TAG=5.10

# Download & extract Archimate tool
RUN set -eux; \
    curl -fsSL --retry 3 -o archi.tgz \
      "https://github.com/archimatetool/archi.io/releases/download/$ARCHI_RELEASE_TAG/Archi-Linux64-$ARCHI_VERSION.tgz"; \
    tar zxf archi.tgz -C /opt/; \
    rm archi.tgz; \
    chmod +x /opt/Archi/Archi; \
    mkdir -p /root/.archi/dropins /archi/report /archi/project

FROM archi AS coarchi
ARG COARCHI_VERSION=0.9.8

# Download & extract Archimate coArchi plugin
RUN set -eux; \
    curl -fsSL --retry 3 -o coarchi.zip \
      "https://www.archimatetool.com/downloads/coarchi/coArchi_$COARCHI_VERSION.archiplugin"; \
    unzip coarchi.zip -d /root/.archi/dropins/ && \
    rm coarchi.zip

FROM coarchi

LABEL org.opencontainers.image.source="https://github.com/burkostya/archimate-ci-image"

COPY entrypoint.sh /opt/Archi/
ENTRYPOINT [ "/opt/Archi/entrypoint.sh" ]
