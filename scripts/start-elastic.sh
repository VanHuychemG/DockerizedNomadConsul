#!/bin/bash

# Start Elastic.
echo 'Starting Elastic...'

chown -R elastic:elastic /var/lib/elasticsearch /opt/elasticsearch

exec su - elastic /opt/elasticsearch/bin/elasticsearch