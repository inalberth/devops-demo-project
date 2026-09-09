# Local GitOps Lab

Laboratório local para exercitar um fluxo GitOps completo com K3D/K3s, Traefik, Argo CD, Helm, OpenBao e External Secrets Operator (ESO).

## Arquitetura

```text
Git repository --> Argo CD --> Helm/Kustomize --> K3D/K3s
                        |                            |
                        |                            v
                        |                 payroll Deployment
                        |                            |
                        v                            v
                 ExternalSecret --> Kubernetes Secret
                        |
                        v
              OpenBao (Docker, host)
```

O bootstrap imperativo instala o cluster, Argo CD e ESO. A partir da aplicação raiz, Argo CD reconcilia os recursos de integração e a aplicação. O volume Raft do OpenBao permanece fora do lifecycle do cluster.

## Pré-requisitos

- Linux com Docker Engine e Compose v2
- `kubectl`, `k3d`, Helm 3, `jq`, `curl`, `envsubst` e `rg`
- portas 80, 443, 8200 e 8201 livres
- `argocd.localhost` e `payroll.localhost` resolvendo para `127.0.0.1` (domínios `.localhost` normalmente já possuem esse comportamento)

Execute `make prerequisites` para verificar as ferramentas.

## Credenciais do OpenBao

Root tokens e unseal keys nunca devem ser gravados neste repositório. O procedimento local usa, por padrão:

```text
~/Documents/devops-lab/openbao-credentials.txt
```

O diretório deve ter modo `0700` e o arquivo `0600`. Para usar outro local, defina `OPENBAO_CREDENTIALS_FILE`. O root token serve somente ao bootstrap administrativo; ESO usa Kubernetes Auth com token temporário e policy restrita.

Para uma instalação nova, execute `bao operator init`, grave imediatamente a saída fora do projeto e forneça três shares a `bao operator unseal`. Nunca faça commit desse material. Se uma credencial for exposta, preserve o acesso atual, faça backup, use `bao operator rotate-keys` e gere/revogue o root token de forma controlada.

## Bootstrap

```bash
make install
make secrets-apply
make payroll-install
make preflight-test
```

`make secrets-apply` é idempotente: converge Kubernetes Auth, policy e role no OpenBao, valida conectividade a partir de um pod e aplica `SecretStore`/`ExternalSecret`. O segredo de demonstração deve existir em `secret/payroll/dev/database` com as propriedades `host`, `port`, `username` e `password`.

`make payroll-install` é uma validação anterior ao GitOps. Assim que um remoto estiver disponível, o Helm release direto pode ser removido e substituído pela aplicação Argo CD.

## Bootstrap GitOps

Inicialize e envie este repositório a um remoto que o `argocd-repo-server` consiga acessar. Para repositório privado, registre credenciais no Argo CD fora do Git. Em seguida:

```bash
export GIT_REPO_URL=https://example.com/owner/dockers.git
export GIT_TARGET_REVISION=main
make gitops-bootstrap
kubectl get applications -n argocd -w
make smoke-test
```

A aplicação raiz renderiza o chart `gitops/bootstrap`, que cria:

- `AppProject/devops-lab` com destinos restritos;
- `Application/payroll-platform` para namespace, identidade e segredos externos;
- `Application/payroll-dev` para o chart da aplicação.

Prune e self-heal valem apenas para os recursos referenciados por essas Applications. OpenBao e seus dados Raft não são gerenciados pelo Argo CD.

## Lifecycle

```bash
make start
make stop
make status
make validate
make smoke-test
make k8s-delete
```

`make k8s-delete` remove somente o cluster K3D. Para remover OpenBao, pare o Compose e trate `openbao/data` separadamente; nenhuma operação padrão apaga esse diretório.

## Diagnóstico

- **OpenBao sealed:** execute `docker exec -it openbao bao operator unseal` três vezes com shares distintas do arquivo externo.
- **SecretStore não fica Ready:** confirme `make openbao-status`, execute `scripts/check-openbao-connectivity.sh` e depois `make openbao-bootstrap`.
- **ExternalSecret não sincroniza:** use `kubectl describe externalsecret payroll-database -n payroll-dev`; não imprima o Secret resultante.
- **Aplicação Argo CD Unknown/Missing:** valide URL, revisão e caminho com `git ls-remote`, depois inspecione `kubectl describe application -n argocd`.
- **Ingress não responde:** confirme que Traefik está saudável e que as portas 80/443 do load balancer K3D estão publicadas.
- **Pod payroll pendente:** confirme primeiro a existência de `secret/payroll-database`; o Deployment depende dele deliberadamente.

## Rollback e recuperação

Para preservar recursos durante diagnóstico, remova primeiro a Application raiz sem cascata. Depois remova explicitamente as Applications filhas ou reverta o Git para a revisão anterior. Não restaure credenciais comprometidas e não apague o volume Raft como parte de um rollback de aplicação.

Os backups criados durante uma recuperação ficam fora do projeto em `~/Documents/devops-lab`. Dados associados a chaves perdidas não devem ser tratados como backup operacional; mantenha-os apenas até confirmar a restauração dos dados úteis e então remova-os conscientemente.
