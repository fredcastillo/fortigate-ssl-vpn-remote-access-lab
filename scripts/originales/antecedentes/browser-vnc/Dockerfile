FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    firefox-esr iproute2 net-tools iputils-ping \
    openssl curl hping3 \
    && apt clean

ENV IP_ADDR=10.21.75.110
ENV PREFIX=25
ENV GATEWAY=10.21.75.1
ENV DNS_SERVER=8.8.8.8

COPY start-network.sh /start-network.sh
RUN chmod +x /start-network.sh
CMD ["/start-network.sh"]
