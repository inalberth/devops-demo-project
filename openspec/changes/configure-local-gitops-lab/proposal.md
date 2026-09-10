## Why

O laboratório possui os principais componentes em execução, mas seu estado foi montado parcialmente de forma imperativa e ainda não entrega um fluxo GitOps reproduzível de ponta a ponta. É necessário transformar o ambiente em uma plataforma local reconstruível, segura o suficiente para desenvolvimento e capaz de demonstrar a entrega de uma aplicação com segredos provenientes do OpenBao.

## What Changes

- Tornar o cluster K3D e os componentes de plataforma reproduzíveis por configuração versionada e comandos idempotentes de instalação, inicialização, verificação e remoção.
- Consolidar a instalação do Argo CD e do External Secrets Operator por Helm com versões fixadas e valores declarativos.
- Declarar o bootstrap do OpenBao, incluindo políticas, autenticação Kubernetes, role da aplicação e procedimento seguro de inicialização e unseal para o laboratório.
- Remover credenciais administrativas e chaves de unseal do conteúdo versionável, documentando sua rotação e armazenamento fora do repositório.
- Integrar External Secrets Operator ao OpenBao por Kubernetes Auth, `SecretStore` e `ExternalSecret` com privilégio mínimo.
- Adotar um bootstrap GitOps no padrão app-of-apps para separar recursos de plataforma e aplicações.
- Preservar e incorporar o histórico e os arquivos existentes do repositório público `inalberth/devops-demo-project`, sem force-push ou descarte do conteúdo remoto.
- Modernizar e implantar a aplicação Java `demo-java-app` já existente, usando seu Helm chart adaptado ao K3D e consumindo um Secret sincronizado do OpenBao.
- Adicionar verificações automatizadas do cluster, reconciliação Argo CD, entrega de segredos e disponibilidade da aplicação.

## Capabilities

### New Capabilities

- `local-platform-bootstrap`: Provisionamento e lifecycle reproduzível do cluster K3D e dos componentes compartilhados da plataforma local.
- `openbao-secret-delivery`: Bootstrap seguro do OpenBao e entrega de segredos a workloads Kubernetes por External Secrets Operator e Kubernetes Auth.
- `gitops-application-delivery`: Bootstrap do Argo CD, organização app-of-apps e entrega declarativa da primeira aplicação Helm.

### Modified Capabilities

Nenhuma. O projeto ainda não possui especificações de capacidades existentes.

## Impact

- Afeta o `Makefile`, a configuração Docker Compose do OpenBao e os recursos sob `infra/`.
- Integra manifests e valores Helm para K3D, External Secrets e bootstrap Argo CD ao conteúdo existente de `inalberth/devops-demo-project`.
- Exige conciliar os históricos Git local e remoto, publicar a revisão integrada e torná-la acessível ao Argo CD.
- Afeta o código, Dockerfile e Helm chart existentes de `demo-java-app`, preservando os demais materiais de CI/CD do remoto.
- Depende de Docker, K3D/K3s, kubectl, Helm, Argo CD, OpenBao, External Secrets Operator e Traefik.
- Exige rotação das credenciais atualmente armazenadas em texto puro antes da validação final.
