#!/bin/bash

if [ "$DEBUG" = true ] ; then
  set -x
fi

set -e

scaffold_dir=$(cd "$(dirname $0)/.." && pwd)
deployment_name="$1"
scalingo_region="${SCALINGO_REGION:-osc-fr1}"

if [ -z "$1" ] ; then
  echo "$0 <gravitee deployment name>"
  exit -1
fi

set -u

cd "$scaffold_dir"

echo "========================="
echo "Creating scalingo apps..."
echo "========================="
echo
scalingo create --remote gateway "${deployment_name}-gr-gateway"
scalingo create --remote api "${deployment_name}-gr-api"
scalingo create --remote portal "${deployment_name}-gr-portal"
scalingo create --remote mgmt "${deployment_name}-gr-mgmt"
scalingo -r api env-set PROJECT_DIR=rest-api GRAVITEE_MODULE=graviteeio-rest-api
scalingo -r portal env-set PROJECT_DIR=portal-ui GRAVITEE_MODULE=graviteeio-portal-ui
scalingo -r mgmt env-set PROJECT_DIR=mgmt-ui GRAVITEE_MODULE=graviteeio-management-ui
scalingo -r gateway env-set PROJECT_DIR=gateway GRAVITEE_MODULE=graviteeio-gateway

echo "========================="
echo "Creating scalingo addons..."
echo "========================="
echo
scalingo -r api addons-add mongodb mongo-starter-512
scalingo -r api addons-add elasticsearch elasticsearch-starter-1024

echo
echo "========================="
echo "Waiting for scalingo addon provisioning..."

while true ; do
  count="$(scalingo -r api env | grep -c MONGO_URL || true)"
  [ "$count" -gt 0 ] && break
  sleep 5
done

echo "✔ MongoDB OK"

while true ; do
  count="$(scalingo -r api env | grep -c ELASTICSEARCH_URL || true)"
  [ "$count" -gt 0 ] && break
  sleep 5
done

echo "✔  ElasticSearch OK"
echo "========================="
echo

admin_username=admin
admin_password=$(openssl rand -base64 18)

echo
echo "========================="
echo "Configuring Gravitee modules"
echo "========================="
scalingo -r api scale web:1:XL
scalingo -r api env-set GRAVITEE_JWT_SECRET="$(openssl rand -hex 32)"
scalingo -r api env-set GRAVITEE_PORTAL_URL="https://${deployment_name}-gr-portal.${scalingo_region}.scalingo.io"
scalingo -r api env-set GRAVITEE_ADMIN_USERNAME="$admin_username" GRAVITEE_ADMIN_PASSWORD="$admin_password"
scalingo -r mgmt env-set MANAGEMENT_API_URL="https://${deployment_name}-gr-api.${scalingo_region}.scalingo.io"
scalingo -r portal env-set MANAGEMENT_API_URL="https://${deployment_name}-gr-api.${scalingo_region}.scalingo.io"
scalingo -r gateway env-set "MONGO_URL=$(scalingo -r api env-get SCALINGO_MONGO_URL)"
scalingo -r gateway env-set "ELASTICSEARCH_URL=$(scalingo -r api env-get SCALINGO_ELASTICSEARCH_URL)"

echo
echo "========================="
echo "Deploying Gravitee modules"
echo "========================="
echo

git push --porcelain api master >deployment-rest-api.log 2>&1 &
git push --porcelain gateway master >deployment-gateway.log 2>&1 &
git push --porcelain mgmt master >deployment-management-ui.log 2>&1 &
git push --porcelain portal master >deployment-portal-ui.log 2>&1 &

wait

echo
echo "========================="
echo "Deployment is over:"
echo "* Management UI: https://${deployment_name}-gr-mgmt.${scalingo_region}.scalingo.io"
echo "* Dev Portal UI: https://${deployment_name}-gr-portal.${scalingo_region}.scalingo.io"
echo "* Gateway:       https://${deployment_name}-gr-gateway.${scalingo_region}.scalingo.io"
echo "* Rest API:      https://${deployment_name}-gr-api.${scalingo_region}.scalingo.io"
echo
echo "→ Admin Username: ${admin_username}"
echo "→ Admin Password: ${admin_password}"
echo "========================="
echo
