# Development of server

The caprover server has three internal parts all deployed in the same image:

- installer - for (re)creating a swarm with a server node that also serves the frontend
- server -
- frontend

There are also 2 support containers

- nginx server
- certbot

## Deployment

### Deploy on a server with occupied 80 and 443 ports

1. [x] Deploy with changed admin(3000) and http(80) ports to for example 13000 and 20080
   - in my case synology-DSM7 has an existing nginx listening on 80 and 443 and own certificate management
2. [x] Certificates with dns not http port 80 that is occupied
   - <https://caprover.com/docs/certbot-config.html#customize-certbot-command-to-use-dns-01-challenge>
3. [ ] Fix redirects when forced https
4. [ ] Caprover-frontend - showing the new ports - low priority

#### Certbot with DNS challange - a must for other ports hosting

```
echo Create a certbot with a similar version with the default one used by caprover: <https://github.com/caprover/caprover/blob/master/src/utils/CaptainConstants.ts#L58>
printf 'FROM certbot/dns-cloudflare:v2.11.0 \n ENTRYPOINT ["/bin/sh", "-c"] \n CMD ["tail -f /dev/null"]' | docker build -t certbot/dns-cloudflare:v2.11.0-caprover-customized -f- .

# keep `'EOF'` otherwise the ${domainName} will be interpolated before writing the file
sudo tee /captain/data/config-override.json <<'EOF'
{
  "skipVerifyingDomains": "true",
  "certbotImageName": "certbot/dns-cloudflare:v2.11.0-caprover-customized",
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

###
