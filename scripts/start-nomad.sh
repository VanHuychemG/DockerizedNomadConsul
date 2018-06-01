#!/bin/bash

# Wait until Consul started and listens on port 8500.
while [ -z "`netstat -tln | grep 8500`" ]; do
  echo 'Waiting for Consul to start ...'
  sleep 1
done
echo 'Consul started.'

# Start Nomad.
echo 'Starting Nomad...'
exec sudo \
  nomad agent \
  -data-dir=/nomad/data \
  -config=/etc/nomad \
  -dev