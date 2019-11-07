#! /bin/bash
set -e

CLEAN_REF=${GITHUB_REF##*/}
BRANCH=${CLEAN_REF:-$1}

PROJECT_NAME="preview"
IMAGE_TAG="preview-${BRANCH}"
DOCKER=/usr/bin/docker
PHP_IMAGE=docker.pkg.github.com/kraynel/preview-formation/php-api-platform
NGINX_IMAGE=docker.pkg.github.com/kraynel/preview-formation/nginx-api-platform

echo "Creating network ${PROJECT_NAME}-${BRANCH}"
if $($DOCKER network ls | grep -q "${PROJECT_NAME}-${BRANCH}")
then
        echo "Network exists"
else
        echo "Network does not exist yet"
        $DOCKER network create ${PROJECT_NAME}-${BRANCH}
fi

$DOCKER pull ${PHP_IMAGE}:${IMAGE_TAG}
$DOCKER pull ${NGINX_IMAGE}:${IMAGE_TAG}

echo "Starting PHP"
$DOCKER stop php-${PROJECT_NAME}-${BRANCH} || true
$DOCKER rm php-${PROJECT_NAME}-${BRANCH} || true
$DOCKER run -d --name php-${PROJECT_NAME}-${BRANCH} --network ${PROJECT_NAME}-db --env-file=/home/ubuntu/preview-formation/.env.prod --network-alias=php ${PHP_IMAGE}:${IMAGE_TAG}
$DOCKER network connect  --alias php ${PROJECT_NAME}-${BRANCH} php-${PROJECT_NAME}-${BRANCH}

echo "Starting NGINX"
$DOCKER stop nginx-${PROJECT_NAME}-${BRANCH} || true
$DOCKER rm nginx-${PROJECT_NAME}-${BRANCH} || true

$DOCKER run -d --name nginx-${PROJECT_NAME}-${BRANCH} --network ${PROJECT_NAME}-${BRANCH} ${NGINX_IMAGE}:${IMAGE_TAG}
$DOCKER network connect --alias nginx-${PROJECT_NAME}-${BRANCH} kong-net nginx-${PROJECT_NAME}-${BRANCH}

echo "Creating Kong service"
if $(curl http://localhost:8001/services/nginx-${PROJECT_NAME}-${BRANCH} | grep -q "Not found")
then
    curl -s -i -X POST \
    --url http://localhost:8001/services/ \
    --data "name=nginx-${PROJECT_NAME}-${BRANCH}" \
    --data "url=http://nginx-${PROJECT_NAME}-${BRANCH}"
fi

echo "Mapping to new url ${BRANCH}"
if $(curl http://localhost:8001/services/nginx-${PROJECT_NAME}-${BRANCH}/routes/preview-${BRANCH} | grep -q "Not found")
then
    curl -s -i -X POST \
    --url http://localhost:8001/services/nginx-${PROJECT_NAME}-${BRANCH}/routes \
    --data "name=preview-${BRANCH}" \
    --data "hosts[]=${BRANCH}.preview.theo.do"
fi