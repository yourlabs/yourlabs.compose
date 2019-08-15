# Tutorial

This is an opinionated presentation of what you can do with docker-compose and
yourlabs.compose.

## docker-compose.yml

We are going to arrange the following compose file:

- docker-compose.yml: the base one
- docker-compose.override.yml: the one that sets up a development environment
  on localhost, mounting the source code, installing dependencies and building
  it from the command overrides, directly binding ports...
- docker-compose.staging.yml: the one that will set up environments that is
  in-between development and production. It will setup mailcatcher and un-named
  volumes too, but will support a load-balancer with a passworded configuration
  (tip: try `bigsudo yourlabs.traefik`),
- docker-compose.production.yml: this one would use bind-mounted directories as
  volumes for persistent data so that you can easily recover disk-space with
  `docker system prune -a --volumes` without risking production data drop.

## .gitlab-ci.yml

And my .gitlab-ci.yml as such:

```yaml
review-deploy:
  image: yourlabs/python
  stage: test
  environment:
    name: test/$CI_COMMIT_REF_NAME
    url: https://${CI_ENVIRONMENT_SLUG}.your.domain
    on_stop: review-stop
  script:
    - HOST=${CI_ENVIRONMENT_SLUG}.your.domain
      IMAGE=$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME
      docker-compose
      -f docker-compose.yml
      -f docker-compose.staging.yml
      --project-name $CI_ENVIRONMENT_SLUG
      up -d
    - ./do waituntil curl --fail $CI_ENVIRONMENT_URL
  except:
    refs:
      - master
      - staging

review-stop:
  stage: test
  image: yourlabs/python
  script:
  - docker-compose -p $CI_ENVIRONMENT_SLUG down --remove-orphans
  - docker-compose -p $CI_ENVIRONMENT_SLUG rm -fsv
  when: manual
  environment:
    action: stop
    name: test/$CI_COMMIT_REF_NAME
  except:
    refs:
      - master
      - staging

staging:
  image: yourlabs/python
  stage: staging
  environment:
    name: staging
    url: https://staging.your.domain
  script:
    - HOST=staging.your.domain
      IMAGE=$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME
      docker-compose
      -f docker-compose.staging.yml
      --project-name $CI_ENVIRONMENT_SLUG
      up -d
    - ./do waituntil curl --fail $CI_ENVIRONMENT_URL
  only:
    refs:
      - master
      - staging

formation:
  image: yourlabs/ansible
  stage: production
  environment:
    name: formation
    url: https://formation.your.domain
  script:
    - export $(echo FORMATION_ENV | xargs)
    - bigsudo yourlabs.compose
      HOST=formation.your.domain
      IMAGE=$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_NAME
      docker-compose
      -f docker-compose.production.yml
      up -d
    - ./do waituntil curl --fail $CI_ENVIRONMENT_URL
  when: manual
  only:
    refs:
      - master
      - formation
```

## The do script

I like to have a do script to encapsulate small bash logic units, it will
display help if executed without arguments and otherwise run the function
specified by the first argument, and forward all extra arguments to that
function.

It looks like the following:

```bash
# waituntil             Wait for a statement until 150 tries elapsed
waituntil() {
    set +x
    printf "$*"
    i=${i-150}
    success=false
    until [ $i = 0 ]; do
        i=$((i-1))
        printf "\e[31m.\e[0m"
        if $* &> ".waituntil.outerr"; then
            printf "\e[32mSUCCESS\e[0m:\n"
            success=true
            break
        else
            sleep 1
        fi
    done
    if ! $success; then
        printf "\e[31mFAILED\e[0m:\n"
    fi
    cat ".waituntil.outerr"
    set -x
}

# compose               Wrapper for docker-compose
#                       Adds an extra command: ./do compose apply
compose() {
    if [ "$1" = "apply" ]; then
        compose build
        compose down
        compose up -d
        compose logs
        compose ps
        return
    fi

    if [ -n "${SUDO_UID-}" ]; then
        export hostuid="$SUDO_UID"
    else
        export hostuid="$UID"
    fi

    docker-compose $@
}

if [ -z "${1-}" ]; then
    grep '^# ' $0
else
    fun=$1
    shift
    set -x
    $fun $*
fi
```
