#!/usr/bin/env bash

function makeArchive()
{
  license=$1
  mkdir -p ../../build/azure/CouchBaseServerAndSyncGateway/
  rm ../../build/azure/CouchbaseServerAndSyncGateway/archive-${license}.zip
  mkdir -p ../../build/tmp

  cp mainTemplate-${license}.json ../../build/tmp/mainTemplate.json
  cp createUiDefinition.json ../../build/tmp
  cp ../scripts/* ../../build/tmp

  cd ../../build/tmp || exit
  zip -r -X ../azure/CouchBaseServerAndSyncGateway/archive-${license}.zip *
  cd - || exit
  rm -rf ../../build/tmp
}

makeArchive byol_2019
makeArchive hourly_pricing_mar19
