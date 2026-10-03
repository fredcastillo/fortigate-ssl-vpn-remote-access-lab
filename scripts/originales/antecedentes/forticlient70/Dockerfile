FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    curl \
    gnupg \
    iproute2 \
    iputils-ping \
    traceroute \
    isc-dhcp-client \
    openssh-client \
    dbus \
    procps \
    net-tools \
    nano \
    less \
    ppp \
    && rm -rf /var/lib/apt/lists/*

RUN wget -qO- https://repo.fortinet.com/repo/7.0/ubuntu/DEB-GPG-KEY \
    | gpg --dearmor -o /usr/share/keyrings/fortinet.gpg

RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/fortinet.gpg] https://repo.fortinet.com/repo/7.0/ubuntu/ /bionic multiverse" \
    > /etc/apt/sources.list.d/fortinet.list

RUN apt-get update \
    && apt-get install -y --no-install-recommends forticlient \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -s /bin/bash vpnuser \
    && mkdir -p /run/user/1000 \
    && chown 1000:1000 /run/user/1000 \
    && echo 'export XDG_RUNTIME_DIR=/run/user/1000' >> /home/vpnuser/.profile

COPY start.sh /usr/local/bin/start.sh

RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
