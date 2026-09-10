## 1. Segurança e fundação do repositório

- [x] 1.1 Remover do conteúdo versionável o arquivo com root token e unseal keys, adicionar regras de ignore e verificar com busca por padrões de credenciais que nenhum material administrativo permanece nos arquivos rastreáveis
- [x] 1.2 Documentar e executar a rotação segura das credenciais OpenBao atualmente expostas, verificando que as credenciais antigas deixam de autenticar e que o servidor pode ser desbloqueado com o novo material guardado fora do repositório
- [ ] 1.3 Inicializar o repositório Git e configurar um remoto acessível pelo Argo CD, verificando a consulta da revisão a partir do repo-server sem registrar credenciais no Git
- [x] 1.4 Criar documentação de pré-requisitos, bootstrap, lifecycle, recuperação e teardown, verificando os comandos documentados em uma revisão passo a passo

## 2. Bootstrap da plataforma local

- [x] 2.1 Criar uma configuração K3D versionada com versão K3s, topologia e portas fixadas, verificando que sua validação passa e que um cluster limpo pode ser criado com três nodes `Ready`
- [x] 2.2 Consolidar os valores e versões do Argo CD em arquivos declarativos e atualizar os comandos de instalação para consumi-los, verificando a release `deployed`, rollout saudável e resposta em `argocd.localhost`
- [x] 2.3 Adicionar valores, versão fixada e operações de instalação/status do External Secrets Operator, verificando a release, seus três controllers e os CRDs de `SecretStore` e `ExternalSecret`
- [x] 2.4 Reorganizar os targets de install/start/stop/status/delete para serem idempotentes e reportarem falhas relevantes, verificando reexecução sem duplicar cluster ou releases e remoção sem apagar dados Raft do OpenBao

## 3. Bootstrap seguro do OpenBao

- [x] 3.1 Fixar a versão da imagem OpenBao e ajustar seus endereços anunciados para o ambiente suportado, verificando versão, estado unsealed e resposta do health endpoint após reinício
- [x] 3.2 Implementar bootstrap idempotente do secrets engine, policy `payroll-read`, Kubernetes Auth e role `payroll-dev`, verificando duas execuções consecutivas e a configuração final pela CLI sem imprimir valores sensíveis
- [x] 3.3 Obter dinamicamente endpoint e CA do cluster e configurar o token reviewer do Kubernetes Auth, verificando uma autenticação bem-sucedida com `payroll-secrets` e rejeição de um ServiceAccount não autorizado
- [x] 3.4 Adicionar validação de conectividade pod-to-OpenBao, verificando que um pod no cluster alcança o health endpoint configurado antes da implantação da aplicação

## 4. Entrega de segredos

- [x] 4.1 Declarar namespace, ServiceAccount `payroll-secrets` e RBAC necessários como recursos GitOps, verificando sua aplicação no namespace `payroll-dev`
- [x] 4.2 Criar um `SecretStore` namespaced para OpenBao usando Kubernetes Auth, verificando que sua condição `Ready` fica verdadeira
- [x] 4.3 Criar um `ExternalSecret` que mapeie somente os campos necessários de `secret/data/payroll/dev/database`, verificando condição saudável e criação do Secret Kubernetes esperado sem exibir seu conteúdo
- [x] 4.4 Validar o comportamento de falha com origem ou identidade inválida e restaurar a configuração, verificando condição de erro útil e ausência de valores sensíveis em eventos e logs coletados

## 5. Aplicação Helm payroll

- [x] 5.1 Criar o Helm chart mínimo da aplicação com Deployment, Service, Ingress e health checks, verificando `helm lint` e renderização válida com os valores de desenvolvimento
- [x] 5.2 Configurar o Deployment para referenciar apenas as chaves necessárias do Secret sincronizado, verificando que chart, valores e manifests renderizados não contêm os valores do OpenBao
- [x] 5.3 Fixar uma imagem reproduzível para o workload demonstrativo e configurar um endpoint que reporte saúde sem revelar segredos, verificando o rollout e as respostas dos probes
- [x] 5.4 Definir o hostname local da aplicação e validar o roteamento Traefik, verificando resposta HTTP bem-sucedida através da porta publicada pelo K3D

## 6. Bootstrap GitOps

- [x] 6.1 Criar a estrutura app-of-apps separando plataforma e aplicações, verificando que todos os caminhos de origem referenciados existem e renderizam recursos válidos
- [ ] 6.2 Criar AppProject e Application da aplicação `payroll-dev` com destino e permissões restritos, verificando que o Argo CD aceita os recursos e não reporta destino ou fonte inválidos
- [ ] 6.3 Criar a Application raiz com ordem de sincronização apropriada para stores, segredos e workload, verificando que a primeira sincronização conclui em `Synced` e `Healthy`
- [ ] 6.4 Habilitar prune e self-heal somente para recursos gerenciados e testar um desvio não sensível, verificando que o Argo CD detecta e restaura o estado Git sem afetar os dados persistentes do OpenBao

## 7. Validação integrada

- [x] 7.1 Adicionar verificações estáticas para Compose, configuração K3D, manifests Kubernetes e charts Helm, verificando que o comando agregado termina com sucesso no estado válido e falha diante de um fixture inválido
- [ ] 7.2 Criar um smoke test sem exposição de valores que valide cluster, releases, OpenBao, `SecretStore`, `ExternalSecret`, Secret, Argo CD, rollout e HTTP, verificando uma execução completa bem-sucedida
- [x] 7.3 Recriar o ambiente a partir das instruções e do estado versionado, verificando idempotência do segundo bootstrap e registrando quaisquer passos manuais inevitáveis
- [x] 7.4 Atualizar a documentação com arquitetura, fronteiras de responsabilidade e diagnóstico de falhas comuns, verificando que os fluxos de bootstrap, primeiro deploy, rotação e rollback correspondem aos comandos finais
