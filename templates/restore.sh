#!/bin/bash
set -eu
export RESTIC_PASSWORD_FILE={{ home }}/.restic_password
set -x
export RESTIC_REPOSITORY={{ lookup('env', 'RESTIC_REPOSITORY') or home + '/restic' }}

pushd {{ home }}
if [ ! -d $RESTIC_REPOSITORY ]; then
    echo 'Repository not found ! geting from ftp'
    lftp -c 'set ssl:check-hostname false;connect {{ lookup("env", "LFTP_DSN") }}; mirror -v {{ home.split("/")[-1] }}/restic {{ home }}/restic'
fi
if [ -z "${1-}" ]; then
    restic snapshots
    exit 0
fi
restic restore $1 --target $PWD
docker-compose down --remove-orphans -v
mv {{ home }}/data/postgres {{ home }}/postgres-backup-data-$(date +%Y%m%d-%H:%M:%S)
docker-compose up -d postgres
until docker-compose exec -T postgres sh -c "test -S /var/run/postgresql/.s.PGSQL.5432"; do
    sleep 1
done
sleep 3 # ugly wait until db starts up, socket waiting aint enough
docker-compose exec -T postgres psql -d django -U django -f /dump/data.dump
docker-compose up -d
retcode=$?
docker-compose logs -f &
logspid=$!
[ $retcode = 0 ] || sleep 30
kill $logspid
echo IF all is fine, please rm {{ home }}/postgres-backup-data-$(date +%Y%m%d-%H:%M:%S)
echo OTHERWISE: good luck! I eard loosing data was a LOT of FUN!!
exit $retcode
