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
  cp  -a "$dir../scripts/." "$dir../../build/tmp/"

  cd "$dir../../build/tmp" || exit
  zip -r -X "$dir../../build/azure/CouchBaseServerAndSyncGateway/azure-cbs-archive-${license}.zip" *
  cd - || exit
  rm -rf "$dir../../build/tmp"
}

makeArchive byol "$SCRIPT_SOURCE"
makeArchive hourly-pricing "$SCRIPT_SOURCE"
