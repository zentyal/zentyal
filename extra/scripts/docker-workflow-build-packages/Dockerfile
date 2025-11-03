FROM ubuntu:jammy

# Meta-data
LABEL org.opencontainers.image.authors="djoven@novadevs.com" \
        version="0.0.1"

ENV ZENTYAL_VERSION="8.0"
ENV EMAIL="packages@zentyal.com"

# Requirements to build Zentyal module packages
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
        curl \
        unzip \
        apt-utils \
        libtest-net-ldap-perl

# Add the Zentyal repository so the package 'zbuildtools' and its dependencies can be installed
RUN echo "deb [signed-by=/etc/apt/trusted.gpg.d/zentyal-${ZENTYAL_VERSION}-packages-org.asc] http://packages.zentyal.org/zentyal ${ZENTYAL_VERSION} main extra" > /etc/apt/sources.list.d/zentyal.list && \
    curl https://keys.zentyal.org/zentyal-${ZENTYAL_VERSION}-packages-org.asc -o /etc/apt/trusted.gpg.d/zentyal-${ZENTYAL_VERSION}-packages-org.asc

# Install the package that generates the Zentyal module package
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y zbuildtools && \
    rm -rf /var/lib/apt/lists/*

# Install AWS CLI
RUN cd /opt/ && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

WORKDIR /srv/

COPY extra/scripts/docker-workflow-build-packages/build-packages.sh /usr/local/bin/build-packages.sh

ENTRYPOINT ["/usr/local/bin/build-packages.sh"]
