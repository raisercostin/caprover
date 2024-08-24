# Development of server

The caprover server has three internal parts all deployed in the same image:

- installer - for (re)creating a swarm with a server node that also serves the frontend
- server - 
- frontend

There are also 2 support containers
- nginx server
- certbot

## Development Scenarios

### Server Changes Local Deploy

Assuming you already have npm installed.
After changes in server you must build, find some frontend already existing (not to bother with compilation there):

```cli
echo build server to $(pwd)/built/ && 
    npm run build
echo add frontend to $(pwd)/dist-frontend/ &&
    printf 'FROM caprover/caprover:1.12.0 AS source \n FROM scratch \n COPY --from=source /usr/src/app/dist-frontend /dist-frontend' | docker buildx build -f- --output . .
echo run server &&
    docker run --rm \
    --name captain-now \
    -e ACCEPTED_TERMS=true \
    -e "CAPTAIN_IS_DEBUG=1" \
    -e "MAIN_NODE_IP_ADDRESS=127.0.0.1" \
    -e "CAPTAIN_HOST_HTTP_PORT=10080" \
    -e "CAPTAIN_HOST_HTTPS_PORT=10443" \
    -e "CAPTAIN_HOST_ADMIN_PORT=13000" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /captain:/captain \
    -v $(pwd):/usr/src/app \
    -w /usr/src/app \
    node:18-alpine \
    node ./built/server.js
docker service logs --follow captain-captain
```
