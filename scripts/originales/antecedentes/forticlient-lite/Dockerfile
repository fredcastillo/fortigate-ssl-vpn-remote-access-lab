FROM ubuntu:22.04
ARG FC_VERSION=7.2
ENV DEBIAN_FRONTEND=noninteractive

# Evita que el postinst intente arrancar servicios durante el build
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates wget curl gnupg iproute2 iputils-ping traceroute \
      isc-dhcp-client openssh-client dbus procps net-tools nano less \
    && wget -qO- https://repo.fortinet.com/repo/forticlient/${FC_VERSION}/ubuntu/DEB-GPG-KEY \
         | gpg --dearmor -o /usr/share/keyrings/repo.fortinet.com.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/repo.fortinet.com.gpg] https://repo.fortinet.com/repo/forticlient/${FC_VERSION}/ubuntu/ stable non-free" \
         > /etc/apt/sources.list.d/repo.fortinet.com.list \
    && apt-get update \
    && (apt-get install -y libindicator3-7 || true) \
    && apt-get install -y --no-install-recommends forticlient \
    && rm -rf /var/lib/apt/lists/*

COPY start.sh /usr/local/bin/start.sh
CMD ["/usr/local/bin/start.sh"]
