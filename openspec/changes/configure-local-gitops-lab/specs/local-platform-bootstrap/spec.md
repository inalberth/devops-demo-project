## Purpose

Define um ambiente Kubernetes local reproduzível e verificável, com lifecycle consistente e componentes de plataforma instalados por configuração declarativa versionada.

## ADDED Requirements

### Requirement: Cluster local reproduzível
O sistema SHALL criar o cluster local com nome, quantidade de servidores e agentes, portas publicadas e versão do Kubernetes definidos em configuração versionada.

#### Scenario: Criação a partir de uma máquina limpa
- **WHEN** um operador executa o bootstrap em uma máquina com os pré-requisitos instalados e sem o cluster
- **THEN** o sistema cria o cluster configurado e todos os nodes atingem o estado `Ready`

#### Scenario: Reexecução do bootstrap
- **WHEN** o operador executa novamente o bootstrap sobre um ambiente já provisionado
- **THEN** o sistema preserva o ambiente e converge para a configuração declarada sem criar um segundo cluster

### Requirement: Lifecycle operacional
O sistema SHALL fornecer operações documentadas para instalar pré-requisitos, iniciar, parar, inspecionar e remover o ambiente local.

#### Scenario: Inspeção de saúde
- **WHEN** o operador solicita o status geral
- **THEN** o sistema informa a saúde do OpenBao, cluster Kubernetes, releases Helm, Argo CD e External Secrets Operator

#### Scenario: Remoção intencional
- **WHEN** o operador solicita explicitamente a remoção do laboratório
- **THEN** o cluster é removido sem apagar implicitamente os dados persistentes do OpenBao

### Requirement: Componentes de plataforma declarativos
O sistema SHALL instalar Argo CD e External Secrets Operator usando versões fixadas e arquivos de valores versionados como fonte de verdade.

#### Scenario: Instalação dos componentes
- **WHEN** o bootstrap da plataforma é executado
- **THEN** as releases configuradas são instaladas ou atualizadas e seus workloads tornam-se saudáveis

#### Scenario: Detecção de falha
- **WHEN** um componente não fica disponível dentro do prazo configurado
- **THEN** o bootstrap termina com erro e identifica o componente que falhou

### Requirement: Roteamento local
O sistema SHALL disponibilizar interfaces HTTP do laboratório por nomes locais previsíveis através do ingress controller do cluster.

#### Scenario: Acesso ao Argo CD
- **WHEN** o cluster e o Argo CD estão saudáveis
- **THEN** a interface do Argo CD responde pelo hostname local documentado
