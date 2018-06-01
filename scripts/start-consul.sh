#!/bin/bash

# Start Consul.
echo 'Starting Consul...'
exec consul agent \
  -data-dir=/consul/data \
  -config-dir=/consul/config \
  -dev \
  -client 0.0.0.0