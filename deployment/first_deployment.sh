#!/bin/bash

DB_BACKUP_DIR=/home/www/db_backup
REVERSE_PROXY_DIR=/home/www/smartplaylist-reverseproxy
SMARTPLAYLIST_BACKEND_DIR=/home/www/spotify-grabtrack
DEPLOYMENT_SCRIPT_DIR=/home/www/deployment
NETWORK_NAME=smartplaylist_network
NGINX_CERT_PATH=/etc/nginx/ssl/live/<your_domain>
LOCAL_CERT_PATH=/etc/letsencrypt/live/<your_domain>

# Create a network if it doesn't exist
docker network inspect $NETWORK_NAME > /dev/null 2>&1 || docker network create -d bridge $NETWORK_NAME

# `rabbitmq_mnesia_dir` should not exist
rm -rf $SMARTPLAYLIST_BACKEND_DIR/rabbitmq_mnesia_dir

docker run -d --network $NETWORK_NAME --env-file $SMARTPLAYLIST_BACKEND_DIR/.env --name db -v $SMARTPLAYLIST_BACKEND_DIR/pgdata_new:/pgdata -v $DB_BACKUP_DIR:/pg_backup postgres:14.1-alpine
docker run -d --network $NETWORK_NAME --env-file $SMARTPLAYLIST_BACKEND_DIR/.env --name adminer adminer:4.8.1
docker run -d --network $NETWORK_NAME --env-file $SMARTPLAYLIST_BACKEND_DIR/.env --name broker -v $SMARTPLAYLIST_BACKEND_DIR/rabbitmq_mnesia_dir:/var/lib/rabbitmq/mnesia -v /var/log/rabbitmq:/data/logs/rabbitmq -v $SMARTPLAYLIST_BACKEND_DIR/rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf rabbitmq:3.11.2-management-alpine
docker run -d --network $NETWORK_NAME --env-file $SMARTPLAYLIST_BACKEND_DIR/.env --name api postgrest/postgrest:v10.0.0
docker run -d --network $NETWORK_NAME --env-file $SMARTPLAYLIST_BACKEND_DIR/.env --name fastapi jkulak/smartplaylist-api

# Deploy www
$DEPLOYMENT_SCRIPT_DIR/deploy_www.sh

# Run reverseproxy (this is why ports are not needed for above containers)
docker run -d --name reverseproxy --network $NETWORK_NAME \
    -p 80:80 -p 443:443 \
    -v $LOCAL_CERT_PATH/fullchain.pem:$NGINX_CERT_PATH/fullchain.pem:ro \
    -v $LOCAL_CERT_PATH/privkey.pem:$NGINX_CERT_PATH/privkey.pem:ro \
    -v $REVERSE_PROXY_DIR/nginx/conf/:/etc/nginx/conf.d/:ro nginx:1.23-alpine

# Deploy app
$DEPLOYMENT_SCRIPT_DIR/deploy_app.sh
