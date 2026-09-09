## Purpose

Define a entrega segura e testável de segredos do OpenBao para workloads Kubernetes, usando identidade de ServiceAccount e políticas de privilégio mínimo.

## ADDED Requirements

### Requirement: Credenciais administrativas fora do repositório
O sistema MUST manter root tokens, unseal keys e outros materiais administrativos do OpenBao fora de arquivos versionáveis e MUST documentar sua geração, armazenamento e rotação.

#### Scenario: Verificação do conteúdo versionado
- **WHEN** o repositório é inspecionado após o bootstrap
- **THEN** nenhum root token ou unseal key está presente nos arquivos rastreados

#### Scenario: Rotação inicial
- **WHEN** credenciais administrativas previamente expostas são detectadas
- **THEN** o procedimento de bootstrap exige sua rotação antes da validação final do laboratório

### Requirement: Bootstrap idempotente do OpenBao
O sistema SHALL configurar, de forma repetível, o secrets engine necessário, políticas de acesso, autenticação Kubernetes e roles vinculadas às identidades das aplicações.

#### Scenario: Primeiro bootstrap
- **WHEN** um OpenBao inicializado e desbloqueado ainda não possui a integração
- **THEN** o bootstrap cria a configuração necessária para a aplicação `payroll`

#### Scenario: Bootstrap repetido
- **WHEN** o bootstrap é executado sobre uma configuração já existente
- **THEN** a configuração converge sem duplicar mounts, policies ou roles

### Requirement: Autenticação por identidade Kubernetes
O External Secrets Operator SHALL autenticar no OpenBao usando Kubernetes Auth e um ServiceAccount dedicado no namespace da aplicação, sem utilizar root token ou token estático de longa duração.

#### Scenario: Identidade autorizada
- **WHEN** o `SecretStore` autentica usando o ServiceAccount `payroll-secrets` em `payroll-dev`
- **THEN** o OpenBao emite um token temporário limitado à política de leitura da aplicação

#### Scenario: Identidade não autorizada
- **WHEN** outro ServiceAccount ou namespace tenta usar a role da aplicação
- **THEN** o OpenBao rejeita a autenticação

### Requirement: Sincronização de segredo
O sistema SHALL declarar um store e um recurso de segredo externo que sincronizem apenas os campos necessários do caminho de desenvolvimento da aplicação para um Secret Kubernetes no mesmo namespace.

#### Scenario: Segredo disponível
- **WHEN** o segredo de origem existe e a autenticação é válida
- **THEN** o External Secrets Operator cria ou atualiza o Secret Kubernetes esperado em `payroll-dev`

#### Scenario: Segredo indisponível
- **WHEN** o caminho, a política ou a conectividade com OpenBao é inválida
- **THEN** o recurso de segredo externo reporta condição não saudável sem expor valores sensíveis em eventos ou logs de validação

### Requirement: Conectividade verificável
O endpoint do OpenBao configurado para consumidores no cluster MUST ser alcançável a partir dos pods e SHALL ser validado antes da implantação da aplicação.

#### Scenario: Endpoint alcançável
- **WHEN** a validação de integração é executada a partir do cluster
- **THEN** o endpoint de saúde do OpenBao responde e o fluxo de autenticação pode prosseguir
