## Purpose

Define o fluxo GitOps de ponta a ponta que registra uma fonte Git, reconcilia plataforma e aplicações e entrega uma aplicação Helm funcional no laboratório local.

## ADDED Requirements

### Requirement: Fonte Git acessível
O sistema MUST manter o estado desejado em um repositório Git inicializado, versionado e acessível ao repo-server do Argo CD.

#### Scenario: Repositório válido
- **WHEN** o bootstrap GitOps é executado
- **THEN** o Argo CD consegue consultar a revisão e os caminhos configurados sem erro de autenticação ou conectividade

#### Scenario: Repositório inacessível
- **WHEN** a fonte Git não pode ser consultada
- **THEN** a validação falha antes de considerar o primeiro deploy concluído e apresenta orientação de correção

### Requirement: Bootstrap app-of-apps
O sistema SHALL possuir uma aplicação raiz que reconcilie separadamente os recursos compartilhados de plataforma e as aplicações do laboratório.

#### Scenario: Sincronização inicial
- **WHEN** a aplicação raiz é instalada no Argo CD
- **THEN** ela descobre e sincroniza os recursos declarados de plataforma e a aplicação `payroll`

#### Scenario: Reconciliação de desvio
- **WHEN** um recurso gerenciado é alterado manualmente no cluster
- **THEN** o Argo CD identifica o desvio e, para recursos com sincronização automática habilitada, restaura o estado versionado

### Requirement: Aplicação Helm de demonstração
O sistema SHALL fornecer um Helm chart válido para uma aplicação `payroll` mínima contendo Deployment, Service, configuração de health checks e parametrização específica do ambiente de desenvolvimento.

#### Scenario: Renderização do chart
- **WHEN** o chart é validado e renderizado com os valores de desenvolvimento
- **THEN** são produzidos recursos Kubernetes válidos para o namespace `payroll-dev`

#### Scenario: Implantação saudável
- **WHEN** o Argo CD sincroniza a aplicação e o segredo requerido está disponível
- **THEN** o workload fica disponível, passa seus health checks e responde pelo endpoint local documentado

### Requirement: Consumo seguro do segredo
A aplicação SHALL consumir o Secret Kubernetes sincronizado pelo External Secrets Operator sem incluir o valor secreto no chart, nos valores Helm ou nos manifests renderizados.

#### Scenario: Segredo injetado
- **WHEN** o pod da aplicação é criado após a sincronização do segredo
- **THEN** ele referencia o Secret pelo nome e recebe somente as chaves configuradas

#### Scenario: Segredo ausente
- **WHEN** o Secret Kubernetes requerido não existe
- **THEN** a aplicação não é considerada saudável e a verificação indica a dependência ausente sem revelar dados sensíveis

### Requirement: Validação do primeiro deploy
O sistema SHALL fornecer uma verificação de ponta a ponta que confirme a saúde da aplicação Argo CD, a sincronização do segredo, o rollout do workload e sua disponibilidade HTTP.

#### Scenario: Primeiro deploy bem-sucedido
- **WHEN** todos os componentes estão configurados e a validação é executada
- **THEN** ela confirma estado `Synced` e `Healthy`, Secret disponível, rollout concluído e resposta HTTP válida
