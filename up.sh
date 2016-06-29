#!/bin/bash
PORT=${PORT:-8080}
echo "Rancher port ${PORT}"
HOST=${HOST:-localhost:${PORT}}
echo "Rancher host ${HOST}"
RANCHER_IP=${DOCKER_IP:-$(ifconfig | grep docker -A1 | grep inet | tr ':' ' ' | awk '{print $3}')}
echo "Rancher ip ${RANCHER_IP}"
PRINT_WAIT=${PRINT_WAIT:-false}

printWait() { if $PRINT_WAIT; then echo -n "."; fi; }
httpWait() { while true; do wget $1 -O - -t 1 2>/dev/null >/dev/null; if [ $? -eq 0 ]; then break; fi; printWait; sleep 1; done }


echo "Killing docker containers"
sudo docker ps -a --no-trunc | awk '{print $1}' | grep -v CONTAINER | xargs docker rm -f || true
echo "Starting docker containers"
sudo docker run -d --restart=always -p ${PORT}:8080 --name rancher-server rancher/server
echo "Waiting for Rancher server to go online"
httpWait ${HOST}

PROJECT_ID=$(curl -s http://${HOST}/v1/projects | jq -r ".data[0].id")
echo "Rancher project id: ${PROJECT_ID}"

TOKEN="$(curl -s http://${HOST}/v1/registrationtokens?projectId=$PROJECT_ID | jq -r '.data[0].token' | grep -v null)"
if [ -z "${TOKEN}" ]; then
   echo "Creating rancher registration token"
   curl -s -X POST http://${HOST}/v1/registrationtokens?projectId=$PROJECT_ID 2>/dev/null >/dev/null
   while [ -z "${TOKEN}" ]; do
      TOKEN="$(curl -s http://${HOST}/v1/registrationtokens?projectId=$PROJECT_ID | jq -r '.data[0].token' | grep -v null)"
   done
fi
echo "Rancher registration token ${TOKEN}"

RANCHER_AGENT="$(curl -s http://${HOST}/v1/registrationtokens?projectId=$PROJECT_ID | jq -r '.data[0].image')"
echo "Docker image for rancher agent ${RANCHER_AGENT}"
sudo docker run  -d --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher $RANCHER_AGENT http://${RANCHER_IP}:${PORT}/v1/scripts/$TOKEN

while true; do if [ $(curl -s http://${HOST}/v1/hosts | jq '.data | length') -gt 0 ]; then break; fi; printWait; sleep 1; done

