#!/bin/bash
set -eu

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed -E 's/[^a-z0-9-]//g' | sed 's/-\+/-/g'
}

apk update
apk add --no-cache git curl jq

echo "level=info msg=starting backup of dashboards labeled with ${BACKUP_LABEL}"

git config --user.name "Grafana Backup"
git config --user.email "grafana-backup@mcathome.ch"

git clone https://oauth2:${BACKUP_GIT_TOKEN}@${BACKUP_GIT_REPO} -o grafana-backup

curl \
  --silent --method GET \
  --header "Authorization: Bearer ${BACKUP_GRAFANA_TOKEN}" \
  --header "Accept: application/json" \
  --output dashboards.json \
 "${BACKUP_GRAFANA_URL}/api/search?query=&tag=${BACKUP_DASHBOARD_TAG}&type=dash-db"

jq -c '.[]' dashboards.json | while read -r item; do
  uid=$(echo "$item" | jq -r '.uid')
  folder=$(echo "$item" | jq -r '.folderTitle')
  title=$(echo "$item" | jq -r '.title' | slugify)

  test -d grafana-backup/$folder || mkdir grafana-backup/$folder

  echo "level=info msg=getting dashboard '$title' ($uid)"

  curl \
    --silent --method GET \
    --header "Authorization: Bearer ${BACKUP_GRAFANA_TOKEN}" \
    --header "Accept: application/json" \
    --output grafana-backup/$folder/$title.json \
   "${BACKUP_GRAFANA_URL}/api/dashboards/uid/$uid"
done
  
cd grafana-backup
git add .
git commit -m "Backup $(date)"
git push
