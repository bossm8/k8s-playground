#!/bin/sh

/nova find \
  --helm \
  --containers \
  --output-file report.json

# Needs Vector HTTP Server Source
# https://vector.dev/docs/reference/configuration/sources/http_server/
wget \
  --post-file="report.json" \
  --header="Content-Type: application/json" \
  ${NOVA_VECTOR_JSON_ENDPOINT}
