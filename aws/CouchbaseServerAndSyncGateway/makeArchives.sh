#!/usr/bin/env bash

SCRIPT_SOURCE=${BASH_SOURCE[0]/%makeArchives.sh/}
mkdir -p "$SCRIPT_SOURCE../../build/aws/CouchbaseServerAndSyncGateway/"
# First we need to replace the URL to the install script based on the root script_url txt
bash "$SCRIPT_SOURCE../../script_url_replacer.sh" "${SCRIPT_SOURCE}embedded_gateway.sh"
bash "$SCRIPT_SOURCE../../script_url_replacer.sh" "${SCRIPT_SOURCE}embedded_server.sh"
node "${SCRIPT_SOURCE}compiler.js" "${SCRIPT_SOURCE}mappings.byol.json" > "$SCRIPT_SOURCE../../build/aws/CouchbaseServerAndSyncGateway/couchbase-byol-amzn-lnx2.template"
node "${SCRIPT_SOURCE}compiler.js" "${SCRIPT_SOURCE}mappings.hourly.json" > "$SCRIPT_SOURCE../../build/aws/CouchbaseServerAndSyncGateway/couchbase-hourlypricing-amzn-lnx2.template"