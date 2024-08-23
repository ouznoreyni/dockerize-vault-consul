FROM alpine:3.14

ENV CONSUL_VERSION 1.10.2

RUN apk --no-cache add \
    bash \
    ca-certificates \
    wget \
    && wget --quiet --output-document=/tmp/consul.zip https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip \
    && unzip /tmp/consul.zip -d /usr/local/bin \
    && rm -f /tmp/consul.zip \
    && chmod +x /usr/local/bin/consul \
    && mkdir -p /consul/data /consul/config

COPY config/consul-config.json /consul/config/config.json

EXPOSE 8300 8301 8301/udp 8302 8302/udp 8500 8600 8600/udp

ENTRYPOINT ["consul"]

CMD ["agent", "-config-dir=/consul/config"]