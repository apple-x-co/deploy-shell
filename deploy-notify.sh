#!/bin/bash

WEBHOOK_URL="https://hooks.slack.com/services/xxx"
BACKSLASHES="\`\`\`"

if [ "${PULL_LOG}" = "NOTIFY TEST" ]; then
    MESSAGE_HEAD="NOTIFY TEST"
else
    if [ `echo "${PULL_LOG}" | grep Fast-forward` ]; then
        MESSAGE_HEAD="デプロイが完了しました。"
    else
        MESSAGE_HEAD="[！] デプロイに失敗しました…。"
    fi
fi

MESSAGE=`cat << EOFMSG
${MESSAGE_HEAD}
${SERVICE_URL}

> ${BACKSLASHES}
$ git pull
${PULL_LOG}

$ git log --oneline -5
${NEW_LOG}
${BACKSLASHES}
EOFMSG`

PAYLOAD=`cat << EOFPAYLOAD
    "channel": "#deploy",
    "username": "deploy.sh (${SERVER_NAME})",
    "icon_emoji": ":rocket:",
    "link_names": 1,
    "text": "${MESSAGE}",
EOFPAYLOAD`

curl -X POST --data-urlencode "payload={${PAYLOAD}}" "${WEBHOOK_URL}"
