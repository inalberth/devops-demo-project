apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devops-lab
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${GIT_REPO_URL}
    targetRevision: ${GIT_TARGET_REVISION}
    path: gitops/bootstrap
    helm:
      parameters:
        - name: repoUrl
          value: ${GIT_REPO_URL}
        - name: targetRevision
          value: ${GIT_TARGET_REVISION}
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
