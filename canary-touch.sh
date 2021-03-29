#!/usr/bin/env bash

while true; do
  echo "$(date)" > /ep/solrHome-master/data/canary.lock
  sleep 5
done
