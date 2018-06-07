#!/bin/bash

# Start Kibana.
echo 'Starting Kibana...'

exec su - kibana node --no-warnings /opt/kibana/src/cli 2>&1