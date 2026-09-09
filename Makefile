SHELL := /bin/bash
.DEFAULT_GOAL := help

CLUSTER_NAME ?= devops-lab
ARGO_NAMESPACE ?= argocd
ARGO_HOST ?= argocd.localhost
ARGO_CHART_VERSION ?= 10.8.2
ESO_NAMESPACE ?= external-secrets
ESO_CHART_VERSION ?= 2.10.0
OPENBAO_DIR ?= openbao
OPENBAO_CONTAINER ?= openbao

.PHONY: help
help:
	@echo "DevOps Lab"
	@echo "  make install             Install/bootstrap local platform"
	@echo "  make start               Start OpenBao and K3D"
	@echo "  make stop                Stop OpenBao and K3D"
	@echo "  make status              Show component health"
	@echo "  make validate            Run static validation"
	@echo "  make secrets-apply       Configure OpenBao and External Secrets"
	@echo "  make payroll-install     Install payroll directly for pre-GitOps testing"
	@echo "  make gitops-bootstrap    Submit root Application (requires GIT_REPO_URL)"
	@echo "  make preflight-test      Validate platform/workload before GitOps"
	@echo "  make smoke-test          Validate the complete GitOps delivery path"
	@echo "  make k8s-delete          Delete only the K3D cluster"

.PHONY: prerequisites
prerequisites:
	@for cmd in docker kubectl k3d helm jq curl envsubst rg; do \
		command -v $$cmd >/dev/null || { echo "Missing prerequisite: $$cmd" >&2; exit 1; }; \
	done

.PHONY: openbao-install openbao-start openbao-stop openbao-status openbao-unseal openbao-logs openbao-bootstrap
openbao-install openbao-start:
	cd $(OPENBAO_DIR) && docker compose up -d

openbao-stop:
	cd $(OPENBAO_DIR) && docker compose stop

openbao-status:
	@docker ps --filter name=$(OPENBAO_CONTAINER)
	@docker exec $(OPENBAO_CONTAINER) bao status

openbao-unseal:
	bash scripts/openbao-unseal.sh

openbao-logs:
	cd $(OPENBAO_DIR) && docker compose logs -f openbao

openbao-bootstrap:
	bash scripts/openbao-bootstrap.sh

.PHONY: k8s-start k8s-stop k8s-delete k8s-status
k8s-start:
	@if k3d cluster list --no-headers 2>/dev/null | awk '{print $$1}' | grep -qx '$(CLUSTER_NAME)'; then \
		k3d cluster start $(CLUSTER_NAME) >/dev/null 2>&1 || true; \
	else \
		k3d cluster create --config infra/k3d/config.yaml; \
	fi
	@kubectl wait --for=condition=Ready nodes --all --timeout=180s

k8s-stop:
	k3d cluster stop $(CLUSTER_NAME)

k8s-delete:
	@echo "Deleting K3D cluster only; OpenBao Raft data is preserved."
	@if docker inspect $(OPENBAO_CONTAINER) --format '{{json .NetworkSettings.Networks}}' 2>/dev/null \
		| jq -e 'has("k3d-$(CLUSTER_NAME)")' >/dev/null; then \
		docker network disconnect k3d-$(CLUSTER_NAME) $(OPENBAO_CONTAINER); \
	fi
	k3d cluster delete $(CLUSTER_NAME)

k8s-status:
	@k3d cluster list
	@kubectl get nodes -o wide
	@kubectl get pods -A

.PHONY: argocd-install argocd-status argocd-password
argocd-install:
	helm repo add argo https://argoproj.github.io/argo-helm --force-update
	helm repo update argo
	helm upgrade --install argocd argo/argo-cd \
		--version $(ARGO_CHART_VERSION) \
		--namespace $(ARGO_NAMESPACE) --create-namespace \
		-f infra/argocd/values.yaml --wait --timeout 5m
	kubectl rollout status deployment/argocd-server -n $(ARGO_NAMESPACE) --timeout=180s

argocd-status:
	@helm status argocd -n $(ARGO_NAMESPACE)
	@kubectl get pods,svc,ingress -n $(ARGO_NAMESPACE)
	@curl -fsS -o /dev/null http://$(ARGO_HOST)

argocd-password:
	@kubectl -n $(ARGO_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
	@echo

.PHONY: external-secrets-install external-secrets-status
external-secrets-install:
	helm repo add external-secrets https://charts.external-secrets.io --force-update
	helm repo update external-secrets
	helm upgrade --install external-secrets external-secrets/external-secrets \
		--version $(ESO_CHART_VERSION) \
		--namespace $(ESO_NAMESPACE) --create-namespace \
		-f infra/external-secrets/values.yaml --wait --timeout 5m

external-secrets-status:
	@helm status external-secrets -n $(ESO_NAMESPACE)
	@kubectl get pods -n $(ESO_NAMESPACE)
	@kubectl get crd secretstores.external-secrets.io externalsecrets.external-secrets.io

.PHONY: secrets-apply secrets-status payroll-install gitops-bootstrap validate preflight-test smoke-test
secrets-apply: openbao-unseal openbao-bootstrap
	bash scripts/check-openbao-connectivity.sh
	kubectl apply -k infra/external-secrets/payroll
	kubectl wait -n payroll-dev --for=condition=Ready secretstore/openbao --timeout=120s
	kubectl wait -n payroll-dev --for=condition=Ready externalsecret/payroll-database --timeout=120s

secrets-status:
	@kubectl get secretstore,externalsecret -n payroll-dev
	@kubectl get secret payroll-database -n payroll-dev

payroll-install:
	helm upgrade --install payroll charts/payroll \
		--namespace payroll-dev --create-namespace -f charts/payroll/values-dev.yaml --wait --timeout 5m

gitops-bootstrap:
	bash scripts/gitops-bootstrap.sh

validate:
	bash scripts/validate.sh

preflight-test:
	REQUIRE_ARGO_APP=false bash scripts/smoke-test.sh

smoke-test:
	bash scripts/smoke-test.sh

.PHONY: install start stop status
install: prerequisites openbao-install k8s-start argocd-install external-secrets-install

start: openbao-start k8s-start

stop: openbao-stop k8s-stop

status: openbao-status k8s-status argocd-status external-secrets-status
