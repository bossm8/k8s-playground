#!/bin/bash
set -eu

slugify() {
  tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed -E 's/[^a-z0-9-]//g' | sed 's/-\+/-/g'
}

echo "level=info msg=starting backup of dashboards tagged with '${BACKUP_DASHBOARD_TAG}'"

test -d grafana-backup && rm -rf grafana-backup
git clone https://oauth2:${BACKUP_GIT_TOKEN}@${BACKUP_GIT_REPO} grafana-backup

curl \
  --silent --request GET \
  --header "Authorization: Bearer ${BACKUP_GRAFANA_TOKEN}" \
  --header "Accept: application/json" \
  --output dashboards.json \
 "${BACKUP_GRAFANA_URL}/api/search?query=&tag=${BACKUP_DASHBOARD_TAG}&type=dash-db"

jq -c '.[]' dashboards.json | while read -r item; do
  uid=$(echo "$item" | jq -r '.uid')
  title=$(echo "$item" | jq -r '.title' | slugify)

  echo "level=info msg=getting dashboard '$title' ($uid)"

  curl \
    --silent --request GET \
    --header "Authorization: Bearer ${BACKUP_GRAFANA_TOKEN}" \
    --header "Accept: application/json" \
    --output $title.json \
   "${BACKUP_GRAFANA_URL}/api/dashboards/uid/$uid"

  folder=$(jq -r '.meta.folderTitle' $title.json)
  test -d grafana-backup/$folder || mkdir grafana-backup/$folder

  echo "level=info msg=storing dashboard '$title' in folder '$folder'"

   jq '.dashboard' $title.json > grafana-backup/$folder/$title.json
   rm -rf $title.json
done
  
cd grafana-backup

git config user.name "Grafana Backup"
git config user.email "grafana-backup@mcathome.ch"

git add .
git commit -m "Backup $(date)" || true
git push

cd -
rm -rf grafana-backup

echo "level=info msg=backup done"
