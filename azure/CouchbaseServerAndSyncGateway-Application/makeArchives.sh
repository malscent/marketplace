#!/usr/bin/env bash

SCRIPT_SOURCE=${BASH_SOURCE[0]/%makeArchives.sh/}

function makeArchive()
{
  license=$1
  dir=$2
  mkdir -p "$dir../../build/azure/CouchBaseServerAndSyncGateway/"
  rm "$dir../../build/azure/CouchbaseServerAndSyncGateway/azure-cbs-archive-${license}.zip"
  mkdir -p "$dir../../build/tmp"

  cp "$dir/mainTemplate-${license}.json" "$dir../../build/tmp/mainTemplate.json"
  cp "$dir/createUiDefinition.json" "$dir../../build/tmp"
  curl -L "https://github.com/couchbase-partners/marketplace-scripts/releases/download/v1.0.4/couchbase_installer.sh" -o "$dir../../build/tmp/couchbase_installer.sh"

  cd "$dir../../build/tmp" || exit
  zip -r -j -X "$dir../../build/azure/CouchBaseServerAndSyncGateway/azure-cbs-archive-${license}.zip" *
  cd - || exit
  rm -rf "$dir../../build/tmp"
}

makeArchive byol "$SCRIPT_SOURCE"
makeArchive hourly-pricing "$SCRIPT_SOURCE"
