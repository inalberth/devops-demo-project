# DevOps Demo Project — Local GitOps Lab

Este repositório preserva a aplicação Java e os materiais de CI/CD do projeto original e acrescenta um laboratório local reproduzível com K3D/K3s, Traefik, Argo CD, Helm, OpenBao e External Secrets Operator (ESO).

## Arquitetura e fronteiras

```text
GitHub --> Argo CD --> Helm/Kustomize --> K3D/K3s --> demo-java-app
                         |                              |
                         +--> ExternalSecret --> Secret+
                                  |
                                  v
                          OpenBao (Docker host)
```

O Makefile executa somente o bootstrap indispensável: cluster, Argo CD, ESO, conectividade e configuração interna do OpenBao. Após a aplicação raiz, o Argo CD reconcilia os recursos declarativos. Jenkins, SonarQube e os charts de logging herdados são materiais de referência e não fazem parte deste primeiro deploy. Os dados Raft e as credenciais administrativas do OpenBao ficam fora do lifecycle do cluster e do Git.

## Pré-requisitos

- Linux com Docker Engine e Compose v2
- `kubectl`, `k3d`, Helm 3, `jq`, `curl`, `envsubst` e `rg`
- portas 80, 443, 8200 e 8201 livres
- `argocd.localhost` e `demo-java-app.localhost` resolvendo para `127.0.0.1`

Valide as ferramentas com `make prerequisites`.

## Credenciais e segredo de demonstração

Root token e unseal keys nunca devem ser gravados no projeto. Por padrão, os scripts leem `~/Documents/devops-lab/openbao-credentials.txt`; use diretório `0700`, arquivo `0600`, ou defina `OPENBAO_CREDENTIALS_FILE`.

O segredo de demonstração deve existir no OpenBao em `secret/demo-java-app/dev/database`, com as propriedades `host`, `port`, `username` e `password`. O bootstrap administrativo usa o root token apenas para convergir a configuração. O ESO autentica depois com o ServiceAccount `demo-java-app-secrets`, token temporário e policy de leitura restrita.

## Primeiro bootstrap e deploy direto

```bash
make install
make app-build
make secrets-apply
make app-install
make preflight-test
```

`make app-build` compila a aplicação em uma imagem multi-stage e importa a tag `demo-java-app:1.0.0-local` nos nodes K3D. `make secrets-apply` é idempotente e converge Kubernetes Auth, policy, role, Service, EndpointSlice, SecretStore e ExternalSecret.

## Bootstrap GitOps

O branch `main` deve estar publicado em `https://github.com/inalberth/devops-demo-project.git`, acessível anonimamente pelo repo-server. Autenticação de escrita deve permanecer no credential helper ou GitHub CLI, nunca em arquivos do projeto.

```bash
export GIT_REPO_URL=https://github.com/inalberth/devops-demo-project.git
export GIT_TARGET_REVISION=main
make gitops-bootstrap
kubectl get applications -n argocd -w
make smoke-test
```

A aplicação raiz cria o `AppProject/devops-lab`, `Application/demo-java-app-platform` e `Application/demo-java-app-dev`. Prune e self-heal alcançam somente os recursos dessas Applications; OpenBao e seus dados persistentes não são gerenciados pelo Argo CD.

## Lifecycle

```bash
make start
make stop
make status
make validate
make smoke-test
make k8s-delete
```

`make k8s-delete` remove somente o cluster. Para remover o OpenBao, pare o Compose e trate `openbao/data` separadamente; nenhuma operação padrão apaga esse diretório.

## Diagnóstico

- **OpenBao sealed:** execute `make openbao-unseal` usando o arquivo externo de credenciais.
- **SecretStore não fica Ready:** confirme `make openbao-status`, rode `scripts/check-openbao-connectivity.sh` e `make openbao-bootstrap`.
- **ExternalSecret falha:** inspecione `kubectl describe externalsecret demo-java-app-database -n demo-dev`; não imprima o Secret.
- **Application Unknown/Missing:** valide URL, revisão e path com `git ls-remote`, depois inspecione `kubectl describe application -n argocd`.
- **Ingress não responde:** confirme Traefik e as portas 80/443 do load balancer K3D.
- **Pod pendente:** confirme `kubectl get secret demo-java-app-database -n demo-dev`; o Deployment depende dele deliberadamente.

## Rollback e recuperação

Remova a Application raiz sem cascata para preservar recursos durante diagnóstico. Depois, remova explicitamente as Applications filhas ou reverta o Git. Não restaure credenciais comprometidas nem apague o Raft durante rollback da aplicação. Backups e material de recuperação ficam fora do projeto, em `~/Documents/devops-lab`.

## Conteúdo original preservado

- `demo-java-app/`: aplicação Spring Boot
- `ci/`: Jenkins e Compose do pipeline original
- `cd/argocd/`: exemplo Argo CD legado
- `helm/logging/`: charts de logging legados
- `devops-demo-project-flow.svg` e `devops-demo-project.gif`: materiais visuais originais
