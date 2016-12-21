FROM nginx:1.11.7-alpine
MAINTAINER Ash Wilson <smashwilson@gmail.com>

#We need to install bash to easily handle arrays
# in the entrypoint.sh script
RUN apk add --update bash \
  certbot \
  openssl openssl-dev ca-certificates \
  && rm -rf /var/cache/apk/* \
  && ln -sf /dev/stdout /var/log/nginx/access.log \ # forward request and error logs to docker log collector
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && mkdir -p /etc/letsencrypt/webrootauth # used for webroot reauth

COPY entrypoint.sh /opt/entrypoint.sh
ADD templates /templates

# Prorts is exposed in nginx:alpine image
# EXPOSE 80 443

ENTRYPOINT ["/opt/entrypoint.sh"]
