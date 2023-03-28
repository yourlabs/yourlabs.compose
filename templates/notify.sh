#!/usr/bin/bash 
{% raw %}

[ -x "$(command -v curl)" ] || (echo "curl is missing" && exit 1)
msg="$1"

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
if [[ -n "$SENDER_PASS" ]] && [[ -n "$SMTP_ADDR" ]]; then
  echo "Sending mails"
  readarray -d ',' -t recs < <(printf '%s' "$REC_EMAIL")
  for i in "${recs[@]}"; do
    rcpt_line+=(--mail-rcpt "$i")
  done
  f=$(mktemp /tmp/alert.XXXXXX)
  {
    echo -e "From: \"$HOSTNAME\" <$SENDER_EMAIL>"
    echo -e "To: $REC_EMAIL"
    echo -e "Subject: [$HOSTNAME] Backup finished $(date +'%e-%b %H:%M:%S'):\n\n$msg"
  } >> "$f"
  curl -s -v --ssl-reqd \
    --url "$SMTP_ADDR" \
    --user "$SENDER_EMAIL:$SENDER_PASS" \
    "${rcpt_line[@]}" \
    --upload-file "$f"
  rm -f "$f"
fi

# Mattermost
if [[ -n "$MATTERMOST_USER_ID" ]] && [[ -n "$CHANNEL_ID" ]] && [[ -n "$MATTERMOST_TOKEN" ]] ; then
  echo "Sending to Mattermost"
  curl -s 'https://yourlabs.chat/api/v4/posts' \
    --header "Authorization: Bearer $MATTERMOST_TOKEN"  \
    --data-raw '{"file_ids":[],
      "message":"'"[$HOSTNAME] Backup finished $(date +'%e-%b %H:%M:%S')"'",
      "user_id":"'"$MATTERMOST_USER_ID"'",
      "channel_id":"'"$CHANNEL_ID"'"}' > /dev/null
fi

# Slack
if [[ -n "$SLACK_WEBHOOK" ]] ; then
  echo "Sending to Slack"
  curl -X POST -H 'Content-type: application/json' --data \
    '{"text":"'"$HOSTNAME"' Backup finished '"$(date)"'"}' \
    "$SLACK_WEBHOOK"
fi
{% endraw %}
