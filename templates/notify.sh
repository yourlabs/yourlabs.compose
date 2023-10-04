#!/usr/bin/bash
{% raw %}

status="$1"
if [[ "$status" -eq 0 ]]; then
  msg="Backup finished `date +'%e-%b %H:%M:%S'`"
else
  msg="Backup failed `date +'%e-%b %H:%M:%S'`"
fi

{% endraw %}
SMTP_ADDR="{{ SMTP_ADDR }}"
SENDER_EMAIL="{{ SENDER_EMAIL }}"
SENDER_PASS="{{ SENDER_PASS }}"
MATTERMOST_TOKEN="{{ MATTERMOST_TOKEN }}"
CHANNEL_ID="{{ CHANNEL_ID }}"
MATTERMOST_USER_ID="{{ MATTERMOST_USER_ID }}"
REC_EMAIL="{{ REC_EMAIL }}"
SLACK_WEBHOOK="{{ SLACK_WEBHOOK }}"
{% raw %}

# Emails
if [[ "$SENDER_PASS" != "" ]] && [[ "$SMTP_ADDR" != "" ]] && [[ $status -ne 0 ]]; then
  readarray -d ',' -t recs <<< "$REC_EMAIL"
  for i in ${recs[@]}; do
    rcpt_line+="--mail-rcpt $i "
  done
  f=$(mktemp /tmp/alert.XXXXXX)
  echo -e "From: \"$HOSTNAME\" <$SENDER_EMAIL>" >> $f
  echo -e "Subject: $msg\n\n failed backup" >> $f
  curl -s  --ssl-reqd \
    --url "$SMTP_ADDR" \
    --user "$SENDER_EMAIL:$SENDER_PASS" \
    --mail-from "$SENDER_EMAIL"  \
    $rcpt_line \
    --upload-file "$f"
  rm -f $f
fi

# Mattermost
if [[ "$MATTERMOST_USER_ID" != "" ]] && [[ "$CHANNEL_ID" != "" ]] && [[ "$MATTERMOST_TOKEN" != "" ]] ; then
  curl -s 'https://yourlabs.chat/api/v4/posts' \
    --header "Authorization: Bearer $MATTERMOST_TOKEN"  \
    --data-raw '{"file_ids":[],
      "message":"'"[$HOSTNAME] $msg"'",
      "user_id":"'"$MATTERMOST_USER_ID"'",
      "channel_id":"'"$CHANNEL_ID"'"}' > /dev/null
fi

# Slack
if [[ "SLACK_WEBHOOK" != "" ]] ; then
  curl -X POST -H 'Content-type: application/json' --data \
    '{"text":"'"[$HOSTNAME] $msg"'"}' \
    "$SLACK_WEBHOOK"
fi
{% endraw %}
