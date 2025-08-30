#!/bin/bash

config="server: https://${KUBE_API_HOST}:9345
token: ${NODE_TOKEN}
"
if [ -n "${WORKER_FLAGS}" ]; then
  config="$config
$(printf '%b' "${WORKER_FLAGS}")"
fi

mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<- EOF
${config}
EOF

# Install RKE2 Agent with the specified Kubernetes version
envVars="INSTALL_RKE2_VERSION=${KUBERNETES_VERSION} INSTALL_RKE2_TYPE=agent"
if [ -n "${CHANNEL}" ]; then
  envVars="${envVars} INSTALL_RKE2_CHANNEL=${CHANNEL}"
fi
if [ -n "${INSTALL_METHOD}" ]; then
  envVars="${envVars} INSTALL_RKE2_METHOD=${INSTALL_METHOD}"
fi

install_cmd="curl -sfL https://get.rke2.io | $envVars sh -"
if ! eval "$install_cmd"; then
    echo "Failed to install rke2-agent"
    exit 1
fi

systemctl enable rke2-agent.service --now
RET=1
until [ ${RET} -eq 0 ]; do
        systemctl start rke2-agent.service
        RET=$?
        sleep 10
done