#!/bin/bash
# Call with GIT_REPO GIT_PATH NAMESPACE

set -e
cd $(mktemp -d)

export TILLER_HOSTNAME=tiller-deploy.${NAMESPACE}
export TILLER_SERVER=server
export USER_NAME=flux-helm-operator


## Create tls using cfssl:
# Provides a secure helm installation.

mkdir tls
pushd tls

# Prep the configuration
echo '{"CN":"CA","key":{"algo":"rsa","size":4096}}' | cfssl gencert -initca - | cfssljson -bare ca -
echo '{"signing":{"default":{"expiry":"43800h","usages":["signing","key encipherment","server auth","client auth"]}}}' > ca-config.json

# Create the tiller certificate
echo '{"CN":"'$TILLER_SERVER'","hosts":[""],"key":{"algo":"rsa","size":4096}}' | cfssl gencert \
  -config=ca-config.json -ca=ca.pem \
  -ca-key=ca-key.pem \
  -hostname="$TILLER_HOSTNAME" - | cfssljson -bare $TILLER_SERVER

# Create a client certificate
echo '{"CN":"'$USER_NAME'","hosts":[""],"key":{"algo":"rsa","size":4096}}' | cfssl gencert \
  -config=ca-config.json -ca=ca.pem -ca-key=ca-key.pem \
  -hostname="$TILLER_HOSTNAME" - | cfssljson -bare $USER_NAME

popd


## Create the RBAC configuration for Tiller:
# Includes rbac for a client service-account.

cat > rbac-config.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flux-tiller
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: flux-tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: flux-tiller
    namespace: $NAMESPACE

---
# Helm client serviceaccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: helm
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: Role
metadata:
  name: tiller-user
  namespace: $NAMESPACE
rules:
- apiGroups:
  - ""
  resources:
  - pods/portforward
  verbs:
  - create
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - list
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: tiller-user-binding
  namespace: $NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: tiller-user
subjects:
- kind: ServiceAccount
  name: helm
  namespace: $NAMESPACE
EOF
kubectl create -f rbac-config.yaml


## Deploy helm with mutual TLS enabled.
# --history-max limits the maximum number of revisions Tiller stores;
# leaving it to the default (0) may result in request timeouts after N
# releases, due to the excessive amount of ConfigMaps Tiller will
# attempt to retrieve.

helm init --upgrade \
  --wait \
  --tiller-namespace $NAMESPACE \
  --service-account flux-tiller \
  --history-max 10 \
  --override 'spec.template.spec.containers[0].command'='{/tiller,--storage=secret}' \
  --tiller-tls \
  --tiller-tls-cert ./tls/server.pem \
  --tiller-tls-key ./tls/server-key.pem \
  --tiller-tls-verify \
  --tls-ca-cert ./tls/ca.pem


## Deploy the Helm Operator
# Creates a K8s tls secret.

kubectl create secret \
  --namespace $NAMESPACE \
  tls helm-client \
  --cert=tls/flux-helm-operator.pem \
  --key=./tls/flux-helm-operator-key.pem

helm repo add fluxcd https://fluxcd.github.io/flux
helm upgrade --install \
  --tls \
  --tls-verify \
  --tls-ca-cert ./tls/ca.pem \
  --tls-cert ./tls/flux-helm-operator.pem \
  --tls-key ././tls/flux-helm-operator-key.pem \
  --tls-hostname $TILLER_HOSTNAME \
  --tiller-namespace $NAMESPACE \
  --namespace $NAMESPACE \
  --set helmOperator.create=true \
  --set helmOperator.createCRD=true \
  --set git.url=$GIT_REPO \
  --set git.path=$GIT_PATH \
  --set helmOperator.tls.enable=true \
  --set helmOperator.tls.verify=true \
  --set helmOperator.tls.secretName=helm-client \
  --set helmOperator.tls.caContent="$(cat ./tls/ca.pem)" \
  --set helmOperator.tillerNamespace=$NAMESPACE \
  flux \
  fluxcd/flux
