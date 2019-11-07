#! /bin/bash
set -e

CLEAN_REF=${GITHUB_REF##*/}
BRANCH=${CLEAN_REF:-$1}

PROJECT_NAME="preview"
IMAGE_TAG="preview-${BRANCH}"
DOCKER=/usr/bin/docker

echo "Delete Kong routes"
ROUTE_IDS=$(curl http://localhost:8001/services/nginx-${PROJECT_NAME}-${BRANCH}/routes | jq -r '.data | map("\(.id)") | .[]')
for ID in $ROUTE_IDS
do
	echo "Deleting $ID"
	curl -i -X DELETE \
    --url http://localhost:8001/services/nginx-${PROJECT_NAME}-${BRANCH}/routes/$ID
done

echo "Delete Kong Service"
curl -i -X DELETE \
    --url http://localhost:8001/services/nginx-${PROJECT_NAME}-${BRANCH}

echo "Stoping PHP"
$DOCKER stop php-${PROJECT_NAME}-${BRANCH} || true
$DOCKER rm php-${PROJECT_NAME}-${BRANCH} || true

echo "Stoping NGINX"
$DOCKER stop nginx-${PROJECT_NAME}-${BRANCH} || true
$DOCKER rm nginx-${PROJECT_NAME}-${BRANCH} || true

echo "Remove network"
$DOCKER network rm ${PROJECT_NAME}-${BRANCH}