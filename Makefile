K8S_NAME        := k8s-playground
COLIMA_PROFILE  := ${K8S_NAME}
COLIMA_HOME     := $(HOME)/.colima/$(COLIMA_PROFILE)

.PHONY: setup-colima create-local-cluster save-local-cluster-kubeconfig destroy-local-cluster

setup-colima:
	mkdir -p $(COLIMA_HOME) || true
	cp .devcontainer/assets/colima.yaml $(COLIMA_HOME)/colima.yaml
	colima start --profile $(COLIMA_PROFILE)

create-local-cluster:
	kind delete cluster --name $(K8S_NAME)
	kind create cluster --name $(K8S_NAME) --config .devcontainer/assets/cluster.yml
	sleep 2
	docker inspect $(K8S_NAME)-control-plane -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
	/bin/bash ./helpers/install-cilium.sh --kind
	sleep 2
	kubectl wait --for=condition=ready pods --namespace=kube-system -l k8s-app=kube-dns --timeout=300s
	kubectl cluster-info | grep -q 127.0.0.1
	flux install --network-policy=false
	echo "${EXTERNAL_REPO_SSH_KEY}" | base64 -d | flux create secret git k8s-playground-vars --private-key-file /dev/stdin --url ssh://git@github.com/bossm8/k8s-playground-vars.git
	echo "${SOPS_AGE_KEY}" | base64 -d | kubectl create secret generic sops-age --namespace flux-system --from-file age.agekey=/dev/stdin
	kubectl create configmap dev-vars -n flux-system \
    --from-literal=ciliumK8sServiceHost=$$(docker inspect $(K8S_NAME)-control-plane -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}') \
    --from-literal=ciliumK8sServicePort=6443 \
    --from-literal=clusterName=k8s-playground-dev
	kubectl kustomize clusters/dev/flux-system | kubectl apply -f - --server-side --force-conflicts

save-local-cluster-kubeconfig:
	@set -e; \
	if [ ! -f $(HOME)/.kube/config ]; then \
		kind get kubeconfig --name $(K8S_NAME) > $(HOME)/.kube/config; \
		echo "kubeconfig written to default location"; \
	else \
		kind get kubeconfig --name $(K8S_NAME) > $(HOME)/.kube/k8s-playground-config; \
		echo "kubeconfig written to $(HOME)/.kube/k8s-playground-config"; \
	fi

destroy-local-cluster:
	kind delete cluster --name $(K8S_NAME)