#!/bin/sh

if ! [ $(id -u) = 0 ]; then
  echo "Must run as sudo or root"
  exit 1
fi

pwd >currentdirectory
#npm install
#(cd .. && npm run build)
#printf 'FROM caprover/caprover:1.12.0 AS source \n FROM scratch \n COPY --from=source /usr/src/app/dist-frontend /dist-frontend' | docker buildx build -f- --output dump2 .

docker swarm leave --force
docker stop captain-debug
docker rm captain-debug
docker service rm $(docker service ls -q)
sleep 1s
docker secret rm captain-salt
#docker build -t captain-debug -f dockerfile-captain.debug .
#docker build --tag mycaprover-all-debug --file dockerfile-captain-local.dev .

#docker build -t captain-local -f dockerfile.local .
rm -rf /captain && mkdir /captain
chmod -R 777 /captain
docker run \
  --name captain-debug \
  -e ACCEPTED_TERMS=true \
  -e "CAPTAIN_IS_DEBUG=1" \
  -e "MAIN_NODE_IP_ADDRESS=127.0.0.1" \
  -e "CAPTAIN_HOST_HTTP_PORT=10080" \
  -e "CAPTAIN_HOST_HTTPS_PORT=10443" \
  -e "CAPTAIN_HOST_ADMIN_PORT=13000" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /captain:/captain \
  -v $(pwd):/usr/src/app \
  captain-local
#  mycaprover-all-debug
#  -v $(pwd):/usr/src/app mycaprover-all-debug
sleep 2s
docker service logs captain-captain --follow
