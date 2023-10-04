FROM yourlabs/python-app:latest

USER root
RUN pacman -Syu --noconfirm ca-certificates mailcap which gettext curl
ENV STATIC_ROOT=/app/public
RUN mkdir -p /spooler/email && chown -R app /spooler
RUN pip3 install djcli

COPY requirements.txt /app
RUN pip3 install -Ur /app/requirements.txt

COPY . /app/

# REMOVE THE FOLLOWING
RUN pip install bigsudo
RUN pacman -Sy --noconfirm ansible --overwrite "usr/lib/python3.*/site-packages/*"
RUN bigsudo roleinstall /app

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
  --spooler=/spooler/email \
  --plugin=python \
  --module=wsgi:application \
  --route '^/static/.* addheader:Cache-Control: public, max-age=7776000' \
  --route '^/js|css|fonts|images|icons|favicon.png/.* addheader:Cache-Control: public, max-age=7776000' \
  --static-map /static=/app/public \
  --static-map /media=/app/media \
  --static-gzip-all \
  --http-socket=0.0.0.0:8000 \
  --chdir=/app \
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
  --offload-threads '%k' \
  --post-buffering=8192 \
  --processes=6 \
  --spooler-chdir=/app \
  --spooler-frequency=1 \
  --spooler-processes=8 \
  --thunder-lock \
  --workers=12 \
  --vacuum"
