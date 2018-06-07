#!/bin/bash

# Start Elastic.
echo 'Starting Elastic...'

exec su - elastic /opt/elasticsearch/bin/elasticsearch 2>&1