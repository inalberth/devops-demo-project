## Context

O diagnóstico inicial encontrou um cluster K3D saudável com Traefik, Argo CD e External Secrets Operator, além de um OpenBao externo ao cluster. A primeira implementação tornou a plataforma e um workload provisório `payroll` reproduzíveis. O remoto escolhido posteriormente, `inalberth/devops-demo-project`, já possui histórico próprio, uma aplicação Spring Boot em `demo-java-app/`, um chart legado em `helm/app/` e materiais de CI/CD que devem ser preservados.

O OpenBao precisa continuar dockerizado fora do cluster nesta mudança. O laboratório deve permanecer simples para uso local, mas demonstrar limites de segurança e reconciliação próximos de um ecossistema real. Veja `proposal.md` para a motivação e os specs para os contratos observáveis.

## Goals / Non-Goals

**Goals:**

- Separar bootstrap imperativo mínimo do estado continuamente reconciliado pelo Argo CD.
- Permitir reconstrução do ambiente por arquivos versionados e comandos idempotentes.
- Demonstrar autenticação workload-to-OpenBao sem credenciais estáticas de aplicação.
- Entregar a aplicação Java existente provando todo o caminho Git -> Argo CD -> Helm -> Kubernetes -> External Secrets -> OpenBao.
- Integrar os históricos local e remoto sem force-push e sem remover os materiais preexistentes do projeto.
- Tornar falhas de conectividade, autenticação e reconciliação diagnosticáveis.

**Non-Goals:**

- Fornecer alta disponibilidade ou segurança de produção para OpenBao, K3D ou aplicações.
- Automatizar unseal com KMS/HSM ou implantar OpenBao dentro do Kubernetes.
- Criar pipelines CI/CD remotos, observabilidade completa ou múltiplos ambientes nesta primeira mudança.
- Ampliar a funcionalidade de negócio da aplicação Java; ela continuará sendo um workload demonstrativo.
- Implantar nesta mudança os componentes legados de Jenkins, SonarQube, logging ou observabilidade presentes no remoto.
- Armazenar unseal keys, root token ou valores de segredos de aplicação no Git.

## Decisions

### Bootstrap em duas camadas

Uma camada imperativa e pequena criará o cluster, instalará Argo CD e preparará a aplicação raiz. Depois disso, Argo CD será responsável por reconciliar os componentes declarativos e aplicações.

Isso evita o problema circular de exigir Argo CD para instalar o próprio Argo CD. A alternativa de manter tudo no Makefile seria mais direta, porém não exercitaria reconciliação GitOps. Instalar todos os componentes pela aplicação raiz também foi descartado porque Argo CD e CRDs indispensáveis precisam existir antes de seus custom resources.

### K3D configurado por arquivo e versões fixadas

As características do cluster serão movidas para uma configuração K3D versionada. Imagens e charts terão versões explícitas, e o Makefile funcionará como interface operacional que consome esses arquivos.

Isso reduz divergência entre flags e arquivos de valores. A atualização de versões continuará intencional, não automática.

### OpenBao externo ao cluster com endereço próprio para workloads

O OpenBao permanecerá no Docker Compose. Para pods, um Service Kubernetes sem selector apontará por EndpointSlice para o gateway da rede Docker, descoberto dinamicamente pelo bootstrap; consumidores usarão somente o DNS estável `openbao-external.demo-dev.svc.cluster.local`. No sentido inverso, o bootstrap conectará o container OpenBao à rede K3D e usará o hostname do load balancer presente no SAN do certificado da API. O endereço anunciado pelo OpenBao para clientes não dependerá de `localhost` dentro do cluster.

A alternativa de implantar OpenBao no K3D simplificaria DNS interno, mas ampliaria o escopo para storage, lifecycle e bootstrap dentro do próprio cluster. Uma futura evolução pode migrá-lo sem alterar o contrato de entrega dos segredos.

### External Secrets com SecretStore namespaced

Será usado um `SecretStore` no namespace `demo-dev`, autenticado com o ServiceAccount `demo-java-app-secrets`. A role do OpenBao ficará vinculada ao nome e namespace exatos e concederá somente a política `demo-java-app-read`, limitada ao caminho `secret/data/demo-java-app/dev/*`.

Um `ClusterSecretStore` facilitaria reutilização, mas aumentaria o alcance da credencial e ocultaria a fronteira de segurança entre aplicações. Novos namespaces deverão declarar stores próprios ou adotar uma abstração futura explícita.

### Configuração do OpenBao por script idempotente

Um script de bootstrap usará a CLI do OpenBao para habilitar/configurar o Kubernetes Auth, aplicar policies e roles e validar o caminho de segredo. Dados administrativos serão recebidos em tempo de execução por ambiente ou entrada segura e nunca gravados pelo script no repositório.

Manifests declarativos puros não configuram APIs internas do OpenBao. Terraform foi considerado, mas adicionaria estado e uma ferramenta extra antes de o laboratório possuir complexidade que justifique isso.

### App-of-apps com separação platform/apps

Uma aplicação raiz apontará para uma árvore declarativa com duas áreas: recursos de plataforma e aplicações. A aplicação Argo CD `demo-java-app-dev` apontará para o chart consolidado em `helm/app` e seus valores específicos do ambiente.

ApplicationSet seria útil ao introduzir vários serviços ou ambientes, mas app-of-apps é suficiente e mais legível para o primeiro deploy. A estrutura deverá permitir a migração futura para ApplicationSet sem mover o chart da aplicação.

### Integração não destrutiva do repositório remoto

O branch remoto `main` será incorporado ao histórico local com um merge explícito de históricos não relacionados. Conflitos serão resolvidos preservando a aplicação, os materiais de CI/CD e arquivos visuais remotos, enquanto a documentação raiz será consolidada com as instruções do laboratório. Não haverá force-push; a publicação deverá ser fast-forward a partir do merge resultante.

Usar um branch GitOps separado evitaria conflitos imediatos, mas manteria dois estados divergentes e não integraria a infraestrutura ao projeto escolhido. Substituir o histórico remoto foi descartado por violar a preservação solicitada.

### Aplicação Java sem dados sensíveis observáveis

O Spring Boot existente será atualizado para uma linha suportada de Java/Spring Boot e receberá Actuator para health checks. O Deployment referenciará chaves de um Secret gerado pelo External Secrets Operator, mas a aplicação não retornará nem registrará seus valores.

O Dockerfile será multi-stage e fixará versões das imagens base. Para o primeiro deploy local, a imagem será construída e importada em todos os nodes K3D com uma tag versionada; o chart usará `IfNotPresent`. Publicar a imagem em registry fica fora do escopo desta mudança.

### Validação em camadas

As verificações serão divididas em sintaxe/renderização, saúde da infraestrutura e teste end-to-end. O status geral deverá interromper em falhas relevantes, enquanto comandos estritamente informativos poderão tolerar componentes ainda não instalados.

## Risks / Trade-offs

- [O gateway da rede Docker variar após recriação] -> Descobrir o gateway em cada bootstrap e reconciliar o EndpointSlice antes de validar o store.
- [A porta da API Kubernetes mudar após recriar o cluster] -> Obter o endpoint atual durante o bootstrap do Kubernetes Auth em vez de manter a porta dinâmica hardcoded.
- [Credenciais já expostas permanecerem válidas] -> Bloquear a conclusão da migração até que unseal keys/root token sejam regenerados e o arquivo inseguro seja removido do conjunto versionável.
- [A publicação no remoto público exigir autenticação de escrita não disponível] -> Configurar autenticação GitHub fora do repositório antes do push; o Argo CD usará acesso anônimo somente leitura.
- [O repositório remoto conter histórico não relacionado e arquivos conflitantes] -> Fazer merge sem force-push, revisar cada conflito e validar que os arquivos remotos continuam presentes antes da publicação.
- [A imagem local não estar disponível em todos os nodes K3D] -> Construir uma tag fixa, importá-la no cluster antes da sincronização e usar `IfNotPresent` no chart.
- [Sincronização automática apagar experimentos manuais] -> Limitar self-heal/prune aos recursos gerenciados e documentar a fronteira; dados persistentes do OpenBao ficam fora do controle do Argo CD.
- [Segredos Kubernetes continuarem armazenados no etcd local] -> Aceitar o risco no laboratório, minimizar escopo e TTL e não posicionar esta arquitetura como configuração de produção.
- [Ordem entre SecretStore, ExternalSecret e Deployment causar rollout falho temporário] -> Usar ondas de sincronização/health checks e considerar o deploy concluído somente após o teste end-to-end.

## Migration Plan

1. Preservar uma cópia segura das credenciais necessárias à recuperação e rotacionar o material atualmente exposto.
2. Inicializar o repositório Git, adicionar regras de ignore e criar um remoto acessível pelo Argo CD.
3. Introduzir configuração K3D e valores Helm versionados, validando-os antes de alterar o cluster existente.
4. Consolidar os targets de bootstrap/lifecycle e instalar ou atualizar os componentes com versões fixadas.
5. Integrar o histórico de `inalberth/devops-demo-project`, preservar sua aplicação e consolidar documentação e chart.
6. Construir/importar a imagem Java e aplicar o bootstrap idempotente do OpenBao com a identidade `demo-java-app-secrets`.
7. Implantar `SecretStore` e `ExternalSecret` e confirmar a criação do Secret Kubernetes.
8. Adicionar a árvore app-of-apps e a aplicação raiz apontando para o chart consolidado.
9. Publicar o merge, sincronizar e executar a validação de ponta a ponta.

Rollback: remover a aplicação raiz do Argo CD sem cascata quando for necessário preservar recursos para diagnóstico; depois remover os recursos da aplicação e stores declarados. Reverter os arquivos Git para a revisão anterior e reaplicar o bootstrap. Não remover automaticamente o volume Raft do OpenBao. Credenciais rotacionadas não serão restauradas para valores comprometidos.
