FROM alpine:3.14

ENV VAULT_VERSION 1.8.2

RUN apk --no-cache add \
    bash \
    ca-certificates \
    wget \
    && wget --quiet --output-document=/tmp/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip \
    && unzip /tmp/vault.zip -d /usr/local/bin \
    && rm -f /tmp/vault.zip \
    && chmod +x /usr/local/bin/vault \
    && mkdir -p /vault/data /vault/config

COPY config/vault-config.json /vault/config/config.json

EXPOSE 8200

ENTRYPOINT ["vault"]

CMD ["server", "-config=/vault/config/config.json"]