## Context

O diagnóstico encontrou um cluster K3D saudável com Traefik, Argo CD e External Secrets Operator, além de um OpenBao externo ao cluster, inicializado e desbloqueado. Parte da integração OpenBao/Kubernetes foi configurada diretamente no estado vivo, mas não existe automação que a reconstrua. Não há `SecretStore`, `ExternalSecret`, aplicação Argo CD ou workload `payroll`, e o diretório ainda não é um repositório Git funcional.

O OpenBao precisa continuar dockerizado fora do cluster nesta mudança. O laboratório deve permanecer simples para uso local, mas demonstrar limites de segurança e reconciliação próximos de um ecossistema real. Veja `proposal.md` para a motivação e os specs para os contratos observáveis.

## Goals / Non-Goals

**Goals:**

- Separar bootstrap imperativo mínimo do estado continuamente reconciliado pelo Argo CD.
- Permitir reconstrução do ambiente por arquivos versionados e comandos idempotentes.
- Demonstrar autenticação workload-to-OpenBao sem credenciais estáticas de aplicação.
- Entregar uma aplicação mínima que prove todo o caminho Git -> Argo CD -> Helm -> Kubernetes -> External Secrets -> OpenBao.
- Tornar falhas de conectividade, autenticação e reconciliação diagnosticáveis.

**Non-Goals:**

- Fornecer alta disponibilidade ou segurança de produção para OpenBao, K3D ou aplicações.
- Automatizar unseal com KMS/HSM ou implantar OpenBao dentro do Kubernetes.
- Criar pipelines CI/CD remotos, observabilidade completa ou múltiplos ambientes nesta primeira mudança.
- Implementar funcionalidade de negócio real do domínio payroll; a aplicação será apenas um workload demonstrativo.
- Armazenar unseal keys, root token ou valores de segredos de aplicação no Git.

## Decisions

### Bootstrap em duas camadas

Uma camada imperativa e pequena criará o cluster, instalará Argo CD e preparará a aplicação raiz. Depois disso, Argo CD será responsável por reconciliar os componentes declarativos e aplicações.

Isso evita o problema circular de exigir Argo CD para instalar o próprio Argo CD. A alternativa de manter tudo no Makefile seria mais direta, porém não exercitaria reconciliação GitOps. Instalar todos os componentes pela aplicação raiz também foi descartado porque Argo CD e CRDs indispensáveis precisam existir antes de seus custom resources.

### K3D configurado por arquivo e versões fixadas

As características do cluster serão movidas para uma configuração K3D versionada. Imagens e charts terão versões explícitas, e o Makefile funcionará como interface operacional que consome esses arquivos.

Isso reduz divergência entre flags e arquivos de valores. A atualização de versões continuará intencional, não automática.

### OpenBao externo ao cluster com endereço próprio para workloads

O OpenBao permanecerá no Docker Compose. Para pods, um Service Kubernetes sem selector apontará por EndpointSlice para o gateway da rede Docker, descoberto dinamicamente pelo bootstrap; consumidores usarão somente o DNS estável `openbao-external.payroll-dev.svc.cluster.local`. No sentido inverso, o bootstrap conectará o container OpenBao à rede K3D e usará o hostname do load balancer presente no SAN do certificado da API. O endereço anunciado pelo OpenBao para clientes não dependerá de `localhost` dentro do cluster.

A alternativa de implantar OpenBao no K3D simplificaria DNS interno, mas ampliaria o escopo para storage, lifecycle e bootstrap dentro do próprio cluster. Uma futura evolução pode migrá-lo sem alterar o contrato de entrega dos segredos.

### External Secrets com SecretStore namespaced

Será usado um `SecretStore` no namespace `payroll-dev`, autenticado com o ServiceAccount `payroll-secrets`. A role do OpenBao ficará vinculada ao nome e namespace exatos e concederá somente a política `payroll-read`.

Um `ClusterSecretStore` facilitaria reutilização, mas aumentaria o alcance da credencial e ocultaria a fronteira de segurança entre aplicações. Novos namespaces deverão declarar stores próprios ou adotar uma abstração futura explícita.

### Configuração do OpenBao por script idempotente

Um script de bootstrap usará a CLI do OpenBao para habilitar/configurar o Kubernetes Auth, aplicar policies e roles e validar o caminho de segredo. Dados administrativos serão recebidos em tempo de execução por ambiente ou entrada segura e nunca gravados pelo script no repositório.

Manifests declarativos puros não configuram APIs internas do OpenBao. Terraform foi considerado, mas adicionaria estado e uma ferramenta extra antes de o laboratório possuir complexidade que justifique isso.

### App-of-apps com separação platform/apps

Uma aplicação raiz apontará para uma árvore declarativa com duas áreas: recursos de plataforma e aplicações. A aplicação `payroll-dev` apontará para seu Helm chart e valores específicos do ambiente.

ApplicationSet seria útil ao introduzir vários serviços ou ambientes, mas app-of-apps é suficiente e mais legível para o primeiro deploy. A estrutura deverá permitir a migração futura para ApplicationSet sem mover o chart da aplicação.

### Aplicação demonstrativa sem dados sensíveis observáveis

O workload mínimo terá health endpoints e confirmará apenas que recebeu a configuração necessária, sem retornar ou registrar o conteúdo do segredo. O Deployment referenciará chaves de um Secret gerado pelo External Secrets Operator.

Uma imagem pública pequena e com versão imutável deverá ser escolhida na implementação. Caso seja criado código de aplicação, ele deve permanecer mínimo e reproduzível; a preferência é evitar um build adicional no primeiro fluxo.

### Validação em camadas

As verificações serão divididas em sintaxe/renderização, saúde da infraestrutura e teste end-to-end. O status geral deverá interromper em falhas relevantes, enquanto comandos estritamente informativos poderão tolerar componentes ainda não instalados.

## Risks / Trade-offs

- [O gateway da rede Docker variar após recriação] -> Descobrir o gateway em cada bootstrap e reconciliar o EndpointSlice antes de validar o store.
- [A porta da API Kubernetes mudar após recriar o cluster] -> Obter o endpoint atual durante o bootstrap do Kubernetes Auth em vez de manter a porta dinâmica hardcoded.
- [Credenciais já expostas permanecerem válidas] -> Bloquear a conclusão da migração até que unseal keys/root token sejam regenerados e o arquivo inseguro seja removido do conjunto versionável.
- [Argo CD depender de um remoto privado sem credenciais configuradas] -> Documentar os modos HTTPS/SSH e validar o acesso antes de criar a aplicação raiz; credenciais do repositório ficam fora do Git.
- [Sincronização automática apagar experimentos manuais] -> Limitar self-heal/prune aos recursos gerenciados e documentar a fronteira; dados persistentes do OpenBao ficam fora do controle do Argo CD.
- [Segredos Kubernetes continuarem armazenados no etcd local] -> Aceitar o risco no laboratório, minimizar escopo e TTL e não posicionar esta arquitetura como configuração de produção.
- [Ordem entre SecretStore, ExternalSecret e Deployment causar rollout falho temporário] -> Usar ondas de sincronização/health checks e considerar o deploy concluído somente após o teste end-to-end.

## Migration Plan

1. Preservar uma cópia segura das credenciais necessárias à recuperação e rotacionar o material atualmente exposto.
2. Inicializar o repositório Git, adicionar regras de ignore e criar um remoto acessível pelo Argo CD.
3. Introduzir configuração K3D e valores Helm versionados, validando-os antes de alterar o cluster existente.
4. Consolidar os targets de bootstrap/lifecycle e instalar ou atualizar os componentes com versões fixadas.
5. Aplicar o bootstrap idempotente do OpenBao e validar a autenticação Kubernetes com a identidade `payroll-secrets`.
6. Implantar `SecretStore` e `ExternalSecret` e confirmar a criação do Secret Kubernetes.
7. Adicionar o chart da aplicação, a árvore app-of-apps e a aplicação raiz.
8. Sincronizar e executar a validação de ponta a ponta.

Rollback: remover a aplicação raiz do Argo CD sem cascata quando for necessário preservar recursos para diagnóstico; depois remover os recursos da aplicação e stores declarados. Reverter os arquivos Git para a revisão anterior e reaplicar o bootstrap. Não remover automaticamente o volume Raft do OpenBao. Credenciais rotacionadas não serão restauradas para valores comprometidos.
