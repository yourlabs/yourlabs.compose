# Deploying a docker-compose.yml to a server

Ansible role to deploy a docker-compose.yml into a home directory, best used
with [bigsudo](https://yourlabs.io/oss/bigsudo).

This README describes the features, see TUTORIAL.md for a tutorial with
opinionated patterns to acheive eXtreme DevOps.

## Example

This role tests itself and you can start copying:

- Dockerfile: will work by default for a CRUDLFA+ project, offer compressed
  and cached static file service and a spooler.
- .gitlab-ci.yml: builds and pushes docker image to the GitLab image registry,
  provides a deployment job YAML template (macro), as well as 3 example
  deployment configurations for different deployment use cases
- docker-compose.yml: for local and ephemeral deployments
- docker-compose.persist.yml: addon to use for persistent deployments, ie.
  are specified in .gitlab-ci.yml

You need to change:

- ci.yourlabs.io with your server in .gitlab-ci.yml
- Gitlab CI variable to set: `$CI_SSH_KEY`, it should contain an ed25510
  private key, you can create one with: `ssh-keygen -t ed25519 -a 100`
- Dockerfile: change the command argument `--module=wsgi:application` with the
  appropriate path to your wsgi application, and uncomment what you want

Then, you can customize all you want!

You may also get more general and conceptual description on the [blog
article about eXtreme DevOps](https://yourlabs.org/posts/2020-02-08-bigsudo-extreme-devops-hacking-operations/)

## Documentation of features

The purpose of this role is to automate deployment of a merge of
docker-compose.yml files into a directory on a host, and automate stuff around
that.

From within a directory with a docker-compose.yml file, you can deploy it in
`$host:/home/staging` with the following command:

    bigsudo yourlabs.compose home=/home/staging $user@$host

If `$user@$host` is not defined, then it will execute on localhost.

You can pass several compose files and environment variables will be proxied
when it generates the final one:

    FOO=bar bigsudo yourlabs.compose \
        home=/home/staging \
        compose_django_image=$YOUR_IMAGE \
        compose=docker-compose.yml,docker-compose.staging.yml

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
