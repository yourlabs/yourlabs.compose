FROM archlinux
RUN useradd --home-dir /app --uid 1000 app && mkdir -p /app && chown -R app /app
WORKDIR /app
RUN pacman -Syu --noconfirm ca-certificates mailcap which gettext python python-pillow python-psycopg2 python-pip python-psutil curl uwsgi uwsgi-plugin-python && rm -rf /var/cache/pacman/pkg
RUN pip3 install --upgrade pip wheel
ENV PYTHONIOENCODING=UTF-8 PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
ENV STATIC_ROOT=/app/public
RUN mkdir -p /spooler/email && chown -R app /spooler
RUN pip3 install djcli

COPY requirements.txt /app
RUN pip3 install -Ur /app/requirements.txt

COPY . /app/

# Build frontend in /app/public:
# RUN DEBUG= ./manage.py ryzom_bundle
# RUN DEBUG= ./manage.py collectstatic --noinput
# RUN find public -type f | xargs gzip -f -k -9

USER app

EXPOSE 8000

# Example Django deployment command
# CMD /usr/bin/bash -euxc "until djcli dbcheck; do sleep 1; done \
#   && ./manage.py migrate --noinput \
#   && uwsgi \

CMD /usr/bin/bash -euxc "uwsgi \
  --http-socket=0.0.0.0:8000 \
  --chdir=/app \
  --spooler=/spooler/email \

  --route '^/static/.* addheader:Cache-Control: public, max-age=7776000' \
  --route '^/js|css|fonts|images|icons|favicon.png/.* addheader:Cache-Control: public, max-age=7776000' \
  --static-map /static=/app/public \
  --static-map /media=/app/media \
  --static-gzip-all \

  --chmod=666 \
  --disable-write-exception \
  --enable-threads \
  --harakiri=1024 \
  --http-keepalive \
  --ignore-sigpipe \
  --ignore-write-errors \
  --log-5xx \
  --master \
  --max-requests=100 \
  --mime-file /etc/mime.types \
  --module=wsgi:application \
  --offload-threads '%k' \
  --plugin=python \
  --post-buffering=8192 \
  --processes=6 \
  --spooler-chdir=/app \
  --spooler-frequency=1 \
  --spooler-processes=8 \
  --thunder-lock \
  --workers=12 \
  --vacuum"
