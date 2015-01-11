# Doppelgänger

Write `.yml` files to define Consul services.

```yml
- name: facebook
  tags: ['master']
  port: 80

- name: twitter
  tags: ['master']
  port: 8080
```

Run the `doppelganger` daemon to register the services with Consul. Send a SIGHUP to refresh. Doppelganger will communicate with a local Consul agent or using the environment variable `CONSUL_HOST`.

The 'doppelganger' tag is used to highlight these new services.


# Installation

```sh
npm install -g redwire-doppelganger
```

This will provide the `doppelganger` command line daemon.

To reload any changes send a SIGHUP to the doppelganger daemon


# Docker Container

A docker container has been provided that bundles Consul 1.4, Doppelganger and Redwire to provide a facade. Check out doppelganger.yml and the examples folder for configuration. Works well with [tugboat](https://github.com/metocean/tugboat).

The image will be available on the docker hub as `metocean/doppelganger` soon.