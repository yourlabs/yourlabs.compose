#!/bin/bash -eux

if [ -z "${BACKUP_FORCE-}" ]; then
  echo This script is not safe to run multiple instances at the same time
  echo Starting through systemctl and forwarding journalctl
  set -eux
  journalctl -fu backup-{{ home.split("/")[-1] }} &
  journalpid="$!"
  systemctl start --wait backup-{{ home.split("/")[-1] }}
  retcode="$?"
  kill $journalpid
  exit $retcode
fi

cd {{ home }}

set -eu
export RESTIC_PASSWORD_FILE={{ home }}/.restic_password
set -x
export RESTIC_REPOSITORY={{ lookup('env', 'RESTIC_REPOSITORY') or home + '/restic' }}

docker-compose up -d postgres
a=0
until docker-compose exec -T postgres sh -c "test -S /var/run/postgresql/.s.PGSQL.5432"; do
    ((a++))
    [[ $a -eq 100 ]] && exit 1
    sleep 1
done

sleep 3 # ugly wait until db starts up, socket waiting aint enough

backup="{{ restic_backup|default('') }}"

docker-compose exec -T postgres sh -c 'pg_dumpall -U $POSTGRES_USER -c -f /dump/data.dump'
docker-compose logs &> log/docker.log || echo "Couldn't get logs from instance"

restic backup $backup docker-compose.yml log ./dump/data.dump {{ restic_backup|default('') }}

{% if lookup('env', 'LFTP_DSN') %}
lftp -c 'set ssl:check-hostname false;connect {{ lookup("env", "LFTP_DSN") }}; mkdir -p {{ home.split("/")[-1] }}; mirror -Rve {{ home }}/restic {{ home.split("/")[-1] }}/restic'
{% endif %}

echo Backup complete, cleaning old backups

rm -rf {{ home }}/dump/data.dump

./prune.sh
