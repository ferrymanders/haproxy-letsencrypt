FROM haproxy:1.8-alpine

MAINTAINER Ferry Manders "docker@blackring.net"

# Add dehydrated & lexicon for letsencrypt

RUN apk add --no-cache \
          bash \
          python-dev \
          py2-pip \
          curl \
          jq \
          openssl \
          bind-tools \
    && apk add --no-cache --virtual .build-deps \
          gcc \
          go \
          git \
          libc-dev \
          libffi-dev \
          openssl-dev \
    && pip install awscli \
    && pip install requests[security] \
    && pip install dns-lexicon \
    && pip install dns-lexicon[route53] \
    && pip install dns-lexicon[transip] \
    && go get github.com/barnybug/cli53/cmd/cli53 \
    && mv /root/go/bin/cli53 /usr/bin/cli53 \
    && go get github.com/ziutek/syslog \
    && go get github.com/ferrymanders/syslog-stdout \
    && mv /root/go/bin/syslog-stdout /usr/bin/syslog-stdout \
    && apk del .build-deps

ADD https://raw.githubusercontent.com/lukas2511/dehydrated/master/dehydrated /usr/bin/dehydrated
ADD https://raw.githubusercontent.com/whereisaaron/dehydrated-route53-hook-script/master/hook.sh /usr/bin/route53_hook.sh
ADD https://raw.githubusercontent.com/ferrymanders/lexicon/master/examples/dehydrated.default.sh /usr/local/bin/lexicon_hook.sh

RUN chmod +x /usr/local/bin/lexicon_hook.sh \
    && chmod +x /usr/bin/dehydrated \
    && chmod +x /usr/bin/route53_hook.sh \
    && mkdir /auth \
    && mkdir -p /usr/local/etc/dehydrated

COPY dehydrated.config  /usr/local/etc/dehydrated/config
COPY scripts /usr/local/scripts
COPY default-page.http /usr/local/etc/haproxy/errors/default-page.http
COPY docker-entrypoint.sh /

VOLUME /config

CMD ["haproxy", "-f", "/config/haproxy.cfg"]