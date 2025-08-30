#!/bin/bash

config="server: https://${KUBE_API_HOST}:6443
token: ${NODE_TOKEN}
"

if [ -n "${WORKER_FLAGS}" ]; then
  config="$config
$(printf '%b' "${WORKER_FLAGS}")"
fi

mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<- EOF
${config}
EOF

# Install K3s Agent with the specified Kubernetes version
envVars="INSTALL_K3S_VERSION=${KUBERNETES_VERSION} INSTALL_K3S_EXEC=agent"

if [ -n "${CHANNEL}" ]; then
  envVars="${envVars} INSTALL_K3S_CHANNEL=${CHANNEL}"
fi

install_cmd="curl -sfL https://get.k3s.io | $envVars sh -"
if ! eval "$install_cmd"; then
    echo "Failed to install k3s-agent"
    exit 1
fi

systemctl enable k3s-agent.service --now
RET=1
until [ ${RET} -eq 0 ]; do
        systemctl start k3s-agent.service
        RET=$?
        sleep 10
done
