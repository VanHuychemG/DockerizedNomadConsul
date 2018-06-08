#!/bin/bash

# Start Kibana.
echo 'Starting Kibana...'

chown -R kibana:kibana /opt/kibana

exec su - kibana /opt/kibana/bin/kibana