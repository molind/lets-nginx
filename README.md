# Let's Nginx

*[dockerhub build](https://hub.docker.com/r/molind/lets-nginx/)*

This is a fork from `smashwilson/lets-nginx`. Main goal was to create tagged docker images for every nginx release.
Small extras on top:
 * Docker Compose examples
 * Less layers inside Dockerfile

Put browser-valid TLS termination in front of any Dockerized HTTP service with one command or few lines in docker-compose.yml.

```bash
docker run --detach \
  --name lets-nginx \
  --link backend:backend \
  --env EMAIL=my@email.com \
  --env DOMAIN=my.site.com \
  --env UPSTREAM=backend:8080 \
  --publish 80:80 \
  --publish 443:443 \
  molind/lets-nginx
```

Issues certificates from [letsencrypt](https://letsencrypt.org/), installs them in [nginx](https://www.nginx.com/), and schedules a cron job to reissue them monthly.

:zap: To run unattended, this container accepts the letsencrypt terms of service on your behalf. Make sure that the [subscriber agreement](https://letsencrypt.org/repository/) is acceptable to you before using this container. :zap:

## Prerequisites

Before you begin, you'll need:

 1. A place to run Docker containers with a public IP.
 2. A domain name with an *A record* pointing to your cluster.

## Usage with Docker Compose

Since new docker container is launched when image version is udpated or config changed, we need to store valuable data inside the volumes. Docker Compose maintains links and volumes for you and it's much easier to manage 5-10 container dependencies and connections from one docker-compose.yml file.

```yml
version: '2'
volumes:
    letsencrypt: {}
    letsencrypt_backups: {}
    dhparam_cache: {}
services:
    nginx:
        image: molind/lets-nginx:latest # Check this repository tags for available versions
        environment:
            - EMAIL=my@email.com
            - DOMAIN=my.site.com
            - UPSTREAM=backend:8080
        depends_on:
            - backend
        ports:
            - "443:443"
            - "80:80"
        volumes:
            - letsencrypt:/etc/letsencrypt
            - letsencrypt_backups:/var/lib/letsencrypt
            - dhparam_cache:/cache
    backend:
# your backend configuration below
```

### Service startup using SystemD

Example below describes how to launch your website containers on system startup as a service. SystemD on Ubuntu 16.04 in my case. Create `/lib/systemd/system/webapp.service` with following contents:

```ini
[Unit]
Description=Webapp docker container

[Service]
User=user
WorkingDirectory=/home/user/docker/webapp
ExecStart=/usr/local/bin/docker-compose up

[Install]
WantedBy=multi-user.target
```

Enable it, to make it auto-start after reboot.
```bash
$ sudo systemctl enable webapp.service
```
And launch.
```bash
$ sudo systemctl start webapp.service
```
To check logs use:
```bash
$ systemctl status webapp.service
```

## Usage

Launch your backend container and note its name, then launch `molind/lets-nginx` with the following parameters:

 * `--link backend:backend` to link your backend service's container to this one. *(This may be unnecessary depending on Docker's [networking configuration](https://docs.docker.com/engine/userguide/networking/dockernetworks/).)*
 * `-e EMAIL=` your email address, used to register with letsencrypt.
 * `-e DOMAIN=` the domain name.
 * `-e UPSTREAM=` the name of your backend container and the port on which the service is listening.
 * `-p 80:80` and `-p 443:443` so that the letsencrypt client and nginx can bind to those ports on your public interface.
 * `-e STAGING=1` uses the Let's Encrypt *staging server* instead of the production one.
            I highly recommend using this option to double check your infrastructure before you launch a real service.
            Let's Encrypt rate-limits the production server to issuing
            [five certificates per domain per seven days](https://community.letsencrypt.org/t/public-beta-rate-limits/4772/3),
            which (as I discovered the hard way) you can quickly exhaust by debugging unrelated problems!
 * `-v {PATH_TO_CONFIGS}:/configs:ro` specify manual configurations for select domains.  Must be in the form {DOMAIN}.conf to be recognized.

### Using more than one backend service

You can distribute traffic to multiple upstream proxy destinations, chosen by the Host header. This is useful if you have more than one container you want to access with https.

To do so, separate multiple corresponding values in the DOMAIN and UPSTREAM variables separated by a `;`:

```bash
-e DOMAIN="domain1.com;sub.domain1.com;another.domain.net"
-e UPSTREAM="backend:8080;172.17.0.5:60;container:5000"
```

## Caching the Certificates and/or DH Parameters

Since `--link`s don't survive the re-creation of the target container, you'll need to coordinate re-creating
the proxy container. In this case, you can cache the certificates and Diffie-Hellman parameters with the following procedure:

Do this once:

```bash
docker volume create --name letsencrypt
docker volume create --name letsencrypt-backups
docker volume create --name dhparam-cache
```

Then start the container, attaching the volumes you just created:

```bash
docker run --detach \
  --name lets-nginx \
  --link backend:backend \
  --env EMAIL=me@email.com \
  --env DOMAIN=mydomain.horse \
  --env UPSTREAM=backend:8080 \
  --publish 80:80 \
  --publish 443:443 \
  --volume letsencrypt:/etc/letsencrypt \
  --volume letsencrypt-backups:/var/lib/letsencrypt \
  --volume dhparam-cache:/cache \
  molind/lets-nginx
```

## Adjusting Nginx configuration

The entry point of this image processes the `nginx.conf` file in `/templates` and places the result in `/etc/nginx/nginx.conf`. Additionally, the file `/templates/vhost.sample.conf` will be processed once for each `;`-delimited pair of values in `$DOMAIN` and `$UPSTREAM`. The result of each will be placed at `/etc/nginx/vhosts/${DOMAINVALUE}.conf`.

The following variable substitutions are made while processing all of these files:

* `${DOMAIN}`
* `${UPSTREAM}`

For example, to adjust `nginx.conf`, create that file in your new image directory with the [baseline content](templates/nginx.conf) and desired modifications. Within your `Dockerfile` *ADD* this file and it will be used to create the nginx configuration instead.

```docker
FROM molind/lets-nginx

ADD nginx.conf /templates/nginx.conf
```
