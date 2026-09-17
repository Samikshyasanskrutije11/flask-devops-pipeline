#!/usr/bin/env bash
# Manually deploy the image to an EC2 host (what Jenkins automates).
# Usage: ./scripts/deploy_manual.sh <ec2-ip> <key.pem> <dockerhub-user/image:tag>
set -euo pipefail

EC2_IP="${1:?ec2 ip required}"
KEY="${2:?path to .pem required}"
IMAGE="${3:?image required}"

ssh -o StrictHostKeyChecking=no -i "$KEY" ubuntu@"$EC2_IP" "
  sudo docker pull ${IMAGE} &&
  sudo docker rm -f flask-app || true &&
  sudo docker run -d --name flask-app --restart unless-stopped \
    -p 80:5000 -e ENVIRONMENT=production ${IMAGE}
"

echo "Deployed. Visit http://${EC2_IP}"
