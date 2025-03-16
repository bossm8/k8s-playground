#!/bin/bash
set -eu

slugify() {
  tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed -E 's/[^a-z0-9-]//g' | sed 's/-\+/-/g'
}

echo "level=info msg=starting backup of dashboards tagged with '${BACKUP_DASHBOARD_TAG}'"

test -d grafana-backup && rm -rf grafana-backup
git clone --quiet https://oauth2:${BACKUP_GIT_TOKEN}@${BACKUP_GIT_REPO} grafana-backup

curl \
  --silent --request GET \
  --header "Authorization: Bearer ${BACKUP_GRAFANA_TOKEN}" \
  --header "Accept: application/json" \
  --output dashboards.json \
 "${BACKUP_GRAFANA_URL}/api/search?query=&tag=${BACKUP_DASHBOARD_TAG}&type=dash-db"

jq -c '.[]' dashboards.json | while read -r item; do
  uid=$(echo "$item" | jq -r '.uid')
  title=$(echo "$item" | jq -r '.title' | slugify)

  echo "level=info msg=checking for existing dashboards with uid '$uid'"

  for file in $(find grafana-backup -type f -iname "*.json"); do
    exuid=$(jq -r '.uid' $file)
    extitle=$(jq -r '.title' $file | slugify)
    if [[ "$exuid" == "$uid" ]] && [[ "$extitle" != "$title" ]]; then
      echo "level=warn msg=found dashboard with same uid but different title, removing the old one: '$file'"
      rm -rf $file
    fi
  done

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

echo "level=info msg=searching for files which have not changed in this backup"
for file in $(find . -type f -mmin +15 -iname "*.json"); do
  echo "level=warn msg=file '$file' has not changed in this backup, moving to '.Deprecated'"
  test -d .Deprecated || mkdir .Deprecated
  test -d .Deprecated/$(dirname $file) || mkdir -p .Deprecated$(dirname $file)
  mv $file .Deprecated/$(dirname $file)
done

git config user.name "Grafana Backup"
git config user.email "grafana-backup@mcathome.ch"

git add .
git commit --quiet --message "Backup $(date)" || true
git push --quiet

cd /workspace
rm -rf grafana-backup

echo "level=info msg=backup finished successfully"
