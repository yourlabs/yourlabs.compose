# Deploying a docker-compose.yml to a server

Ansible role to deploy a docker-compose.yml into a home directory, best used
with [bigsudo](https://yourlabs.io/oss/bigsudo).

## Bigsudo brief introduction

This role can be used normally with ansible but it's a bit boring because you
will have to make sure dependencies are installed and make an inventory
repository or pass a whole bunch of options on the command line.

If you don't know bigsudo, it's a thin wrapper CLI on top of ansible that
allows to execute ansible roles with some automation, such as automatic role
download and recursive role dependencies download, and it will provide a more
condensed output plugin by default. Basically you can do the following things:

    # first argument is role name or path or git repo url
    # then pass as many extra vars as you want with varname=value
    # starting from the first argument that starts with a dash: bigsudo will
    # forward everything directly to ansible-playbook
    bigsudo some.role somevar=foo -v

    # by default it runs on localhost, but you can specify a host with @host or
    # with a user with user@host:
    bigsudo some.role somevar=foo -v

Refer to bigsudo documentation for details.

## Using yourlabs.compose

The purpose of this role is to automate deployment of a docker-compose.yml file
into a directory on a host, and automate stuff around that.

From within a directory with a docker-compose.yml file, you can deploy it in
`$host:/home/staging` with the following command:

    bigsudo yourlabs.compose home=/home/staging $user@$host

Or, you can specify an alternate path or URL to the docker-compose.yml file to deploy:

    bigsudo yourlabs.compose home=/home/yourproject compose=http://.../docker-compose.yml

### Directory generation

This role can also pre-create directories with a given uid, gid and mode, with
the `io.yourlabs.compose.mkdir` label as such:

    volumes:
    - "./log/admin:/app/log"
    labels:
    - "io.yourlabs.compose.mkdir=./app/log:1000:1000:0750"

This will result in the creation of the `{{ home }}/log/admin` directory with
owner 1000 and group 1000 and mode 0750.

### Environment generation

Another interresting feature is automatic environment provisionning with each
variable declared in service environment that is defined at runtime. For
example with this in docker-compose.yml:

    environment:
    - FOO

Then executing the yourlabs.compose role with the FOO variable defined as such:

    FOO=bar bigsudo yourlabs.compose home=/home/test

Will result in the following environment:

    environment:
    - FOO=bar

### YAML overrides on the CLI

You can also add or override service values with the
`compose_servicename_keyname` variable. Example overridding the
`compose[services][django][image]` value on the fly:

    bigsudo yourlabs.compose home=/home/test compose_django_image=yourimage

You can empty values on the fly if you want, just pass empty values, ie. to
make `compose[services][django][build]` empty pass `compose_django_build=`
without value. In the case where you don't clone your repo in the home
directory, then docker-compose would yell if it doesn't find the path to the
Dockerfile, this circumvents that limitation:

    bigsudo yourlabs.compose home=/home/test compose_django_build=

### Network automation

Networks can also be a bit tricky to manage with docker-compose, for example
we typically have a `web` network with a load balancer such as traefik. This
appends the `web` network to the django service, and that it will automatically
attach the network if present by declaring the `web` network as external in the
docker-compose.yml file it deploys:

    bigsudo yourlabs.compose home=/home/test compose_django_networks=web

If you're doing the docker-compose.yml of your load balancer then you have the
opposite issue: docker-compose.yml declares a `web` network as external, but
docker-compose up will not create it and would fail as such:

    ERROR: Network web declared as external, but could not be found. Please
    create the network manually using `docker network create lol` and try again.

This role does prevent this issue by parsing `docker-compose.yml` for external
networks and use the `docker_network` ansible module to pre-create on the host
it if necessary.

### As ansible role

Finnaly, you can use this role like any other ansible role, if you want to wrap
it in more tasks in your repo:

    - name: Ensure docker was setup once on this host
      include_role: name=yourlabs.compose
      vars:
        home: /home/yourthing
        compose_django_image: foobar
        compose_django_build:
        compose_django_networks:
        - web
