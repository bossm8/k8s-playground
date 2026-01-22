.PHONY: create-local-cluster
create-local-cluster:
	kind delete cluster --name k8s-playground
	kind create cluster --name k8s-playground --config .devcontainer/assets/cluster.yml
	kubectl wait --for=condition=ready pods --namespace=kube-system -l k8s-app=kube-dns
	kubectl cluster-info | grep -q 127.0.0.1
	flux install
	kubectl kustomize clusters/dev/flux-system | kubectl apply -f - --server-side --force-conflicts

.PHONY: save-local-cluster-kubeconfig
save-local-cluster-kubeconfig:
	@set -e; \
	if [ ! -f $(HOME)/.kube/config ]; then \
		kind get kubeconfig --name k8s-playground > $(HOME)/.kube/config; \
		echo "kubeconfig written to default location"; \
	else \
		kind get kubeconfig --name k8s-playground > $(HOME)/.kube/local-fleet-cluster; \
		echo "kubeconfig written to $(HOME)/.kube/k8s-playground"; \
	fi

.PHONY: destroy-local-cluster
destroy-local-cluster:
	kind delete cluster --name k8s-playground