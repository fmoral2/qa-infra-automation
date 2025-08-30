#!/bin/bash

config="server: https://${KUBE_API_HOST}:6443
token: ${NODE_TOKEN}
write-kubeconfig-mode: 644
tls-san:
  - ${FQDN}
  - ${KUBE_API_HOST}
"

if [ -n "${SERVER_FLAGS}" ]; then
  config="$config
$(printf '%b' "${SERVER_FLAGS}")"
fi

# Parse NODE_ROLE into an array (comma-separated)
IFS=',' read -r -a ROLES <<< "$NODE_ROLE"

# Initialize role flags
has_etcd=false
has_cp=false
has_worker=false

# Check for specific roles
for role in "${ROLES[@]}"; do
  case "$role" in
    etcd) has_etcd=true ;;
    cp) has_cp=true ;;
    worker) has_worker=true ;;
  esac
done

# Configure K3s based on the role combinations
if [[ "$has_etcd" == true && "$has_cp" == true && "$has_worker" == false ]]; then
  echo "Configuring etcd-cp node"
  config="$config
node-taint:
  - node-role.kubernetes.io/control-plane:NoSchedule
  - node-role.kubernetes.io/etcd:NoExecute
"
elif [[ "$has_etcd" == true && "$has_worker" == true && "$has_cp" == false ]]; then
  echo "Configuring etcd-worker node"
  config="$config
disable-apiserver: true
disable-controller-manager: true
disable-scheduler: true
"
elif [[ "$has_etcd" == true && "$has_cp" == false && "$has_worker" == false ]]; then
  echo "Configuring etcd-only node"
  config="$config
disable-apiserver: true
disable-controller-manager: true
disable-scheduler: true
node-taint:
  - node-role.kubernetes.io/etcd:NoExecute
"
fi

# K3s uses default Flannel CNI

echo "${config}"

mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<- EOF
${config}
EOF

# Install K3s Server with the specified Kubernetes version
envVars="INSTALL_K3S_VERSION=${KUBERNETES_VERSION}"
if [ -n "${CHANNEL}" ]; then
  envVars="${envVars} INSTALL_K3S_CHANNEL=${CHANNEL}"
fi

install_cmd="curl -sfL https://get.k3s.io | $envVars sh -"
if ! eval "$install_cmd"; then
    echo "Failed to install k3s-server"
    exit 1
fi

systemctl enable k3s.service --now
RET=1
until [ ${RET} -eq 0 ]; do
        systemctl start k3s.service
        RET=$?
        sleep 10
done
