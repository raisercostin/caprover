# Development of server

The caprover server has three internal parts all deployed in the same image:

- caprover - single image containing the parts:
- installer - for (re)creating a service (and a swarm). Is a small part of backend that just bootstraps.
- backend - administrative server of entire swarm
- frontend - administrative UI

There are also 2 support containers

- nginx - reverse proxy and certificate hosting
- certbot - certificates creator. Can be swapped.
- caprover/netdata:v1.34.1 - optional
- registry - optional

## Deployment

### Deploy on a server with occupied 80 and 443 ports

1. [x] Deploy with changed admin(3000) and http(80) ports to for example 13000 and 20080
   - in my case synology-DSM7 has an existing nginx listening on 80 and 443 and own certificate management
2. [x] Certificates with dns not http port 80 that is occupied
   - <https://caprover.com/docs/certbot-config.html#customize-certbot-command-to-use-dns-01-challenge>
3. [x] Fix redirects when forced https
4. [ ] Caprover-frontend - showing the new ports - low priority
5. [ ] Check netdata urls
6. [ ] Check self hosted registry
7. [ ] Check adding nodes

#### Certbot with DNS challange - a must for other ports hosting

```shell
echo Create a certbot with a similar version with the default one used by caprover: <https://github.com/caprover/caprover/blob/master/src/utils/CaptainConstants.ts#L58>
printf 'FROM certbot/dns-cloudflare:v2.11.0 \n ENTRYPOINT ["/bin/sh", "-c"] \n CMD ["tail -f /dev/null"]' | docker build -t raisercostin/certbot-dns-cloudflare:v2.11.0-daemon -f- .
docker push raisercostin/certbot-dns-cloudflare:v2.11.0-daemon

# keep `'EOF'` otherwise the ${domainName} will be interpolated before writing the file
sudo tee /captain/data/config-override.json <<'EOF'
{
  "skipVerifyingDomains": "true",
  "certbotImageName": "raisercostin/certbot-dns-cloudflare:v2.11.0-daemon",
  "certbotCertCommandRules": [
    {
      "domain": "*",
      "command":  "certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/captain-cloudflare.token -d ${domainName}" 
    }
  ]
}
EOF

echo check file is ok && sudo cat /captain/data/config-override.json

printf "# Cloudflare API token used by Certbot \n dns_cloudflare_api_token = ***add token here***" | sudo tee /captain/data/letencrypt/etc/captain-cloudflare.token && 
  sudo chmod 600  /captain/data/letencrypt/etc/captain-cloudflare.token

docker service update captain-captain --force
```

##### Check logs

docker service logs captain-captain --follow
The logs should not have old call with --webroot -w but new one with dns
`captain-certbot certbot certonly --webroot -w /captain-webroot/captain.lap1.namekis.com -d captain.lap1.namekis.com --non-interactive`

Logs should be like:

```
| August 25th 2024, 7:32:09.908 am    Verifying Captain owns domain: photos.lap1.namekis.com
| August 25th 2024, 7:32:10.911 am    Enabling SSL for: photos
| August 25th 2024, 7:32:10.914 am    Enabling SSL for photos.lap1.namekis.com
| August 25th 2024, 7:32:10.924 am    executeCommand Container: captain-certbot certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/captain-cloudflare.token -d photos.lap1.namekis.com --non-interactive
| August 25th 2024, 7:32:33.364 am    ########### Saving debug log to /var/log/letsencrypt/letsencrypt.log
| Requesting a certificate for photos.lap1.namekis.com
| Waiting 10 seconds for DNS changes to propagate
|
| Successfully received certificate.
| Certificate is saved at: /etc/letsencrypt/live/photos.lap1.namekis.com/fullchain.pem
| Key is saved at:         /etc/letsencrypt/live/photos.lap1.namekis.com/privkey.pem
| This certificate expires on 2024-11-23.
| These files will be updated when the certificate renews.
|
| NEXT STEPS:
| - The certificate will need to be renewed before it expires. Certbot can automatically renew the certificate in the background, but you may need to take steps to enable that functionality. See https://certbot.org/renewal-setup for instructions.
|
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
| If you like Certbot, please consider supporting our work by:
|  * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
|  * Donating to EFF:                    https://eff.org/donate-le
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
|
| August 25th 2024, 7:32:33.365 am    Saving debug log to /var/log/letsencrypt/letsencrypt.log
| Requesting a certificate for photos.lap1.namekis.com
| Waiting 10 seconds for DNS changes to propagate
|
| Successfully received certificate.
| Certificate is saved at: /etc/letsencrypt/live/photos.lap1.namekis.com/fullchain.pem
| Key is saved at:         /etc/letsencrypt/live/photos.lap1.namekis.com/privkey.pem
| This certificate expires on 2024-11-23.
| These files will be updated when the certificate renews.
|
| NEXT STEPS:
| - The certificate will need to be renewed before it expires. Certbot can automatically renew the certificate in the background, but you may need to take steps to enable that functionality. See https://certbot.org/renewal-setup for instructions.
|
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
| If you like Certbot, please consider supporting our work by:
|  * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
|  * Donating to EFF:                    https://eff.org/donate-le
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
|
| August 25th 2024, 7:32:33.377 am    Updating Load Balancer - ServiceManager
```

## Development Scenarios

### Fast local deploy of backend

Assuming you already have npm installed.
After changes in server you must build, find some frontend already existing (not to bother with compilation there):

```cli
echo build server to $(pwd)/built/ && 
    npm run build
echo add frontend to $(pwd)/dist-frontend/ &&
    printf 'FROM caprover/caprover:1.12.0 AS source \n FROM scratch \n COPY --from=source /usr/src/app/dist-frontend /dist-frontend' | docker buildx build -f- --output . .
echo The debug image `captain-debug:latest` is latest `caprover/caprover:latest` image. We don't need to build it as `/captain` and `/usr/src/app` will be local.
docker tag  caprover/caprover:latest captain-debug
echo Run server using latest caprover image but anyway with current app volume. The same volume will be mounted by installer.&&
    docker run --rm \
    --name captain-now \
    -e ACCEPTED_TERMS=true \
    -e "CAPTAIN_IS_DEBUG=1" \
    -e "MAIN_NODE_IP_ADDRESS=127.0.0.1" \
    -e "CAPTAIN_HOST_HTTP_PORT=23080" \
    -e "CAPTAIN_HOST_HTTPS_PORT=23443" \
    -e "CAPTAIN_HOST_ADMIN_PORT=23000" \
    -e NODE_OPTIONS='--inspect-publish-uid=http,stderr --inspect=38000 --require source-map-support/register' \
    -p 38000:38000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /captain:/captain \
    -v $(pwd):/usr/src/app \
    -w /usr/src/app \
    captain-debug:latest \
    node ./built/server.js

echo You should see something like \
    Debugger listening on ws://127.0.0.1:38000/6bc8d88a-bfc4-43eb-8916-8b642e59d78f \
    For help, see: https://nodejs.org/en/docs/inspector \
    Captain Starting ... \
echo use --inspect-brk=38000 instead to wait for the debugging process to connect

docker service logs --follow captain-captain
```

### Development Snapshot with Existing Frontend

This is fastest if no changes are needed in frontend.

```shell
echo build with latest released frontend version
docker build -t raisercostin/caprover-snapshot:1.12.0 -f dockerfile-captain.snapshot .

echo build with specific frontend version
docker build -t raisercostin/caprover-snapshot -f dockerfile-captain.snapshot --build-arg CAPROVER_FRONTEND_VERSION=1.12.0 .

echo "Test it. Add CAPROVER_IMAGE (default value: caprover/caprover and captain-debug if CAPTAIN_IS_DEBUG=1)"
docker run --rm --name captain-now -e DEBUG_SOURCE_DIRECTORY=$(pwd) -e CAPROVER_IMAGE=raisercostin/caprover-snapshot -e SHOW_DOCKER_COMMANDS=true -e ACCEPTED_TERMS=true -e "CAPTAIN_IS_DEBUG=1" -e "MAIN_NODE_IP_ADDRESS=127.0.0.1" -e "CAPTAIN_HOST_HTTP_PORT=15001" -e "CAPTAIN_HOST_HTTPS_PORT=15000" -e "CAPTAIN_HOST_ADMIN_PORT=15002" -v /var/run/docker.sock:/var/run/docker.sock -v /captain:/captain raisercostin/caprover-snapshot

echo push it to be used elsewere
docker push raisercostin/caprover-snapshot:1.12.0
```

### Development Snapshot with Latest Frontend

```shell
echo build with latest released frontend version
docker build -t raisercostin/caprover-snapshot-all -f dockerfile-captain.snapshot-all .
```
