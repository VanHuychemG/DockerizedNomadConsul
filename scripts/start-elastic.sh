#!/bin/bash

# Start Elastic.
echo 'Starting Elastic...'

exec su - elastic -c "./bin/elasticsearch"