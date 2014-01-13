#!/usr/bin/bash

set -o xtrace
set -o errexit

TOP=$(cd $(dirname $0)/; pwd)
if [[ ! -f "$TOP/upgrade-all.sh" ]]; then
    echo "$0: fatal error: must run this from the incr-upgrade dir" >&2
    exit 1
fi

# Add the SAPI 'amonredis' service:
SDCAPP=$(sdc-sapi /applications?name=sdc | json -Ha uuid)
SAPIURL=$(sdc-sapi /services?name=redis | json -Ha 'metadata["sapi-url"]')
ASSETSIP=$(sdc-sapi /services?name=redis | json -Ha 'metadata["assets-ip"]')
USERSCRIPT=$(/usr/node/bin/node -e 'console.log(JSON.stringify(require("fs").readFileSync("/usbkey/default/user-script.common", "utf8")))')
DOMAIN=$(sdc-sapi /applications?name=sdc | json -Ha metadata.datacenter_name).$(sdc-sapi /applications?name=sdc | json -Ha metadata.dns_domain)
IMAGE_UUID=$(sdc-imgadm list name=amonredis -H -o uuid | tail -1)

if [[ -z "$IMAGE_UUID" ]]; then
    echo "$0: fatal error: no 'amonredis' image uuid in IMGAPI to use" >&2
    exit 1
fi

json -f ./sapi/amonredis/amonredis_svc.json \
    | json -e "application_uuid=\"$SDCAPP\"" \
    | json -e "params.image_uuid=\"$IMAGE_UUID\"" \
    | json -e "metadata[\"sapi-url\"]=\"$SAPIURL\"" \
    | json -e "metadata[\"assets-ip\"]=\"$ASSETSIP\"" \
    | json -e "metadata[\"user-script\"]=$USERSCRIPT" \
    | json -e "metadata[\"SERVICE_DOMAIN\"]=\"amonredis.${DOMAIN}\"" \
    > ./amonredis-service.json
SERVICE_UUID=$(sdc-sapi /services -X POST -d@./amonredis-service.json | json -H uuid)


cat <<EOM >./update-sdc-app.json
{
    "metadata" : {
        "AMONREDIS_SERVICE" : "amonredis.$DOMAIN",
        "amonredis_domain" : "amonredis.$DOMAIN"
    }
}
EOM
sapiadm update $SDCAPP -f ./update-sdc-app.json

# Add amonredis' manifest
M_UUID=$(sdc-sapi /manifests -X POST -d@./sapi/amonredis/manifest.json | json -H uuid)
sdc-sapi /services/$SERVICE_UUID -X PUT -d"{\"manifests\":{\"redis\":\"$M_UUID\"}}"

# Provision.
cat <<EOM | sapiadm provision
{
    "service_uuid" : "$SERVICE_UUID",
    "params" : {
        "alias" : "amonredis0"
    }
}
EOM

