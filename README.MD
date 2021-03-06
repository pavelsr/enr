# enr - Easy nginx redirects

[![Docker Stars](https://img.shields.io/docker/stars/pavelsr/enr.svg?style=flat-square)](https://hub.docker.com/r/pavelsr/enr/)
[![Docker Pulls](https://img.shields.io/docker/pulls/pavelsr/enr.svg?style=flat-square)](https://hub.docker.com/r/pavelsr/enr/) [![MicroBadger Layers](https://img.shields.io/microbadger/layers/pavelsr/enr.svg?style=flat-square)](https://hub.docker.com/r/pavelsr/enr/) [![MicroBadger Size](https://img.shields.io/microbadger/image-size/pavelsr/enr.svg?style=flat-square)](https://hub.docker.com/r/pavelsr/enr/)

Docker container that automatically creates nginx redirects from yaml config file and sync changes

Build your own nameserver for redirects and manage configuration at one place!

E.g. using this service you can create free tilda landings on your own domain ;)

# Problem

Sometimes you need to create alias from some domain to other domain or even url

Usually it's done by CNAME DNS records

But!

1) CNAME record can't handle urls. So you can't create subdomain bitlinks like `q.example.com -> https://docs.google.com/forms/*`

2) In case of such services like Tilda CNAME DNS records wouldn't work without payment `¯\_(ツ)_/¯`

# Solution

You can use this service :wink:

# Running (5 easy steps)

1) Get VDS and install nginx on it.

For easy nginx setup personally I'm using [nginx-proxy](https://github.com/jwilder/nginx-proxy) docker container

2) Place all required redirects in yaml file, e.g. :

```yaml
somedomain.ru: somedomain.tilda.ws
```

3) Find path to your nginx config

If you are using [nginx-proxy](https://github.com/jwilder/nginx-proxy) you can define default.config path using `jq`:

```bash
docker inspect nginx | jq '.[].Mounts[] | select(.Destination == "/etc/nginx/conf.d") .Source' | tr -d '"'
```

4) Start docker container (do it at same folder where `config.yaml` placeddocker):

```bash
docker run -d --name enr --privileged --restart=always \
-v $(pwd)/config.yaml:/app/config.yaml \
-v /var/lib/docker/volumes/839fde5b09a48a2385ef388d35b4c00293702e3d1e9b52057915b4414d84ee17/_data/default.conf:/app/nginx.conf \
-v /var/run/docker.sock:/var/run/docker.sock \
pavelsr/enr
```

(don't forget to change `/app/config.yaml` and `/app/nginx.conf` volumes to your own path)

`--privileged` mode is used to automatically reload nginx config.


5) Don't forget to create A records to VDS IP address for any domain in yaml config file

6) Profit!

# How it works

Service monitors config.yaml using Linux::Inotify2 and sync changes with nginx config instantly

Moreover it monitors nginx config each minute (you can change interval to your own). It's usefull when nginx config is fully created automatically, like with [nginx-proxy](https://github.com/jwilder/nginx-proxy). So after server reboot you don't need to touch `config.yaml`, it will synced automatically

App is written in Perl, for managing watchers it uses [AnyEvent](https://metacpan.org/pod/AnyEvent)

For auto nginx reloading it uses `docker kill -s HUP nginx` command, for that docker `--privileged` mode and `/var/run/docker.sock` volume are required

Badges in this readme brought by [shields.io](http://shields.io/)

# docker run options

As alternative you can use [docker-compose file](https://github.com/pavelsr/enr/blob/master/docker-compose.yml)

If you just want to minimize resources usage and monitor config file only each minute please run as ` docker run ... pavelsr/enr /usr/sbin/crond -f`. Appropriate command is already addded to `/etc/crontabs/root`.

Also you setup via `ENR_INTERVAL` env variable how often in seconds app will check nginx config (by default `60`):

```bash
docker run -d --name enr --privileged --restart=always \
-v $(pwd)/config.yaml:/app/config.yaml \
-v /var/lib/docker/volumes/839fde5b09a48a2385ef388d35b4c00293702e3d1e9b52057915b4414d84ee17/_data/default.conf:/app/nginx.conf \
-v /var/run/docker.sock:/var/run/docker.sock \
-e "ENR_INTERVAL=300" \
-e "ENR_DISABLE_INOTIFY=1" \
pavelsr/enr
```

# ENV variables

```bash
$ grep -o -P "ENR_\w+" manage.pl | sort -u
ENR_DISABLE_INOTIFY     # to disable inotify feature and use only AnyEvent timer
ENR_INTERVAL            # interval for AnyEvent timer, in seconds, by default 60
ENR_NGINX_CFG_PATH      # path to config.yaml relative to WORKDIR
ENR_NGINX_RELOAD_CMD    # nginx reload cmd, by default  docker kill -s HUP nginx
ENR_YAML_CFG_PATH       # path to nginx.conf relative to WORKDIR
```

# TO DO

Move Redirects::Nginx at separate repository and publish it on cpan

# Troubleshoting

Before create github issue please check is your redirects successfully recognized: `docker exec -it enr perl manage.pl -n`

Also you can check nginx.conf directly: `docker exec -it enr tail -n 10 nginx.conf` and `tail -n 10 $(docker inspect enr | jq '.[].Mounts[] | select(.Destination == "/app/nginx.conf") .Source' | tr -d '"')`

If no please double check docker volume paths

```bash
docker inspect enr | jq '.[].Mounts[] | select(.Destination == "/app/nginx.conf") .Source' | tr -d '"'
```

Also if there are no inotify event after config file changed try to restart enr container

App is working fine only if you are not modifying server redirect directives in nginx config using some other software or docker container

Otherwise correctness is not guaranteed (since I haven't tested app in interaction with other app despite nginx-proxy)

If you see docker single file volume sync bug (like [this](https://github.com/docker/for-win/issues/1392)), try to use folders:

```bash
docker run -d --name enr --privileged --restart=always \
-v $(pwd)/config.yaml:/app/config.yaml \
-v /var/lib/docker/volumes/839fde5b09a48a2385ef388d35b4c00293702e3d1e9b52057915b4414d84ee17/_data/:/app/nginx \
-v /var/run/docker.sock:/var/run/docker.sock \
-e "ENR_NGINX_CFG_PATH=/app/nginx/default.conf" \
pavelsr/enr
```

Also make sure that you run container from folder where config.yml present

# Donations

If you like my work please consider to make a donation

Paypal: `pavel.p.serikov@gmail.com`

Bitcoin: 19vCkPyQvjYZ6gkYaNfE51gzHzpAPZ6STj

Ethereum: 0x2bdd2dbb9d08ee30ce25877381eae725a21f2ba9
