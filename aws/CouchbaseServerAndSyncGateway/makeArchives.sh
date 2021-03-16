#!/usr/bin/env bash

SCRIPT_SOURCE=${BASH_SOURCE[0]/%makeArchives.sh/}
mkdir -p "$SCRIPT_SOURCE../../build/aws/CouchbaseServerAndSyncGateway/"

node "$SCRIPT_SOURCE/compiler.js" "$SCRIPT_SOURCE/mappings.byol.json" > "$SCRIPT_SOURCE../../build/aws/CouchbaseServerAndSyncGateway/couchbase-byol-amzn-lnx2.template"
node "$SCRIPT_SOURCE/compiler.js" "$SCRIPT_SOURCE/mappings.hourly.json" > "$SCRIPT_SOURCE../../build/aws/CouchbaseServerAndSyncGateway/couchbase-hourlypricing-amzn-lnx2.template"