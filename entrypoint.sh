#!/bin/bash

if [[ -z $EMAIL || -z $DOMAINS || -z $SECRET ]]; then
	echo "EMAIL, DOMAINS, SECRET env vars required"
	env
	exit 1
fi

if [[ ! -z $STAGING ]]; then
    STAGING=--staging
fi

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

cd $HOME
python3 -m http.server 80 &
PID=$!
certbot certonly --webroot -w $HOME -n --agree-tos --email ${EMAIL} ${STAGING} --no-self-upgrade -d ${DOMAINS}
kill $PID

CERTPATH=/etc/letsencrypt/live/$(echo $DOMAINS | cut -f1 -d',')

ls $CERTPATH || exit 1

cat /secret-patch-template.json | \
	sed "s/NAMESPACE/${NAMESPACE}/" | \
	sed "s/NAME/${SECRET}/" | \
	sed "s/TLSCERT/$(cat ${CERTPATH}/fullchain.pem | base64 | tr -d '\n')/" | \
	sed "s/TLSKEY/$(cat ${CERTPATH}/privkey.pem |  base64 | tr -d '\n')/" \
	> /secret-patch.json

ls /secret-patch.json || exit 1

# update secret
curl -v --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    -k -v -XPATCH  -H "Accept: application/json, */*" \
    -H "Content-Type: application/strategic-merge-patch+json" \
    -d @/secret-patch.json https://${KUBERNETES_SERVICE_HOST}/api/v1/namespaces/${NAMESPACE}/secrets/${SECRET}

if [[ ! -z $DEPLOYMENT ]]; then
   cat /deployment-patch-template.json | \
	sed "s/TLSUPDATED/$(date)/" | \
	sed "s/NAMESPACE/${NAMESPACE}/" | \
	sed "s/NAME/${DEPLOYMENT}/" \
	> /deployment-patch.json

    ls /deployment-patch.json || exit 1

    # update pod spec on ingress deployment to trigger redeploy
    curl -v --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
        -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -k -v -XPATCH \
        -H "Accept: application/json, */*" -H "Content-Type: application/strategic-merge-patch+json" \
        -d @/deployment-patch.json https://${KUBERNETES_SERVICE_HOST}/apis/extensions/v1beta1/namespaces/${NAMESPACE}/deployments/${DEPLOYMENT}
fi

