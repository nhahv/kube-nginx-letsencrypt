#/bin/bash

docker build --tag nhahv/kube-nginx-letsencrypt:latest .

docker push nhahv/kube-nginx-letsencrypt:latest

