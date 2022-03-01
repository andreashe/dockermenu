DockerControl is a menu for easier create images and send them to
a artifact storage like nexus.


# Inside the project

Create a docker folder with these files:
- docker-compose.yml
- deployment.yml
- profile.yml
- dockerfile

## docker-compose.yml

It must hold at least this information:

```
---
networks:
  default:
    external:
      name: mynetworkname
services:
version: '3.7'
```

## deployment.yml

Here the artifact repositories must be placed like:

```
---
repository:
  release: nexus.mydomain.com:9001/repository/docker-releases
  snapshot: nexus.mydomain.com:9000/repository/docker-snapshots
version: 1.0.0
```

## profile.yml

Is the part required to rebuild a docker compose file. Content like:

```
title: my-software
desc: this is a test image
version: latest
container: my-software-container
service: my-software
compose:
  image: mycompany/my-software
  restart: always
  build:
   context: .
   dockerfile: dockerfile
   args:
     - http_proxy=
     - https_proxy=
     - no_proxy=localhost,127.0.0.1,::1
  container_name: my-software-container
  ports:
   - "80:80"
```

## dockerfile
for example:
```
FROM adoptopenjdk/openjdk11
```

# Global config file

Create the following config file:

```
  ~/.dockermenu.yml
```

with this content:

```
---
projects:
  - <path to your dockermenu project>
```

If using git bash, the path starts with something like /c/Users

# License

This software is free and can be used and modified. It can also be used for commercial purpose but not sold.
