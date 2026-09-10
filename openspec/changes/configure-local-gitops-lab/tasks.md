## 1. Segurança e fundação do repositório

- [x] 1.1 Remover do conteúdo versionável o arquivo com root token e unseal keys, adicionar regras de ignore e verificar com busca por padrões de credenciais que nenhum material administrativo permanece nos arquivos rastreáveis
- [x] 1.2 Documentar e executar a rotação segura das credenciais OpenBao atualmente expostas, verificando que as credenciais antigas deixam de autenticar e que o servidor pode ser desbloqueado com o novo material guardado fora do repositório
- [ ] 1.3 Integrar sem force-push o histórico existente de `inalberth/devops-demo-project`, configurar esse remoto e publicar o merge, verificando preservação dos arquivos remotos e consulta da revisão pelo repo-server sem registrar credenciais no Git
- [ ] 1.4 Consolidar a documentação remota com pré-requisitos, bootstrap, lifecycle, recuperação e teardown do laboratório, verificando os comandos documentados em uma revisão passo a passo

## 2. Bootstrap da plataforma local

- [x] 2.1 Criar uma configuração K3D versionada com versão K3s, topologia e portas fixadas, verificando que sua validação passa e que um cluster limpo pode ser criado com três nodes `Ready`
- [x] 2.2 Consolidar os valores e versões do Argo CD em arquivos declarativos e atualizar os comandos de instalação para consumi-los, verificando a release `deployed`, rollout saudável e resposta em `argocd.localhost`
- [x] 2.3 Adicionar valores, versão fixada e operações de instalação/status do External Secrets Operator, verificando a release, seus três controllers e os CRDs de `SecretStore` e `ExternalSecret`
- [x] 2.4 Reorganizar os targets de install/start/stop/status/delete para serem idempotentes e reportarem falhas relevantes, verificando reexecução sem duplicar cluster ou releases e remoção sem apagar dados Raft do OpenBao

## 3. Bootstrap seguro do OpenBao

- [x] 3.1 Fixar a versão da imagem OpenBao e ajustar seus endereços anunciados para o ambiente suportado, verificando versão, estado unsealed e resposta do health endpoint após reinício
- [ ] 3.2 Adaptar o bootstrap idempotente para policy `demo-java-app-read`, caminho de segredo e role `demo-java-app-dev`, verificando duas execuções consecutivas e a configuração final pela CLI sem imprimir valores sensíveis
- [ ] 3.3 Configurar a role para `demo-java-app-secrets` em `demo-dev`, verificando autenticação bem-sucedida dessa identidade e rejeição de um ServiceAccount não autorizado
- [x] 3.4 Adicionar validação de conectividade pod-to-OpenBao, verificando que um pod no cluster alcança o health endpoint configurado antes da implantação da aplicação

## 4. Entrega de segredos

- [ ] 4.1 Declarar namespace `demo-dev`, ServiceAccount `demo-java-app-secrets` e conectividade necessários como recursos GitOps, verificando sua aplicação no namespace alvo
- [ ] 4.2 Criar um `SecretStore` namespaced para OpenBao usando Kubernetes Auth, verificando que sua condição `Ready` fica verdadeira em `demo-dev`
- [ ] 4.3 Criar um `ExternalSecret` que mapeie somente os campos necessários de `secret/data/demo-java-app/dev/database`, verificando condição saudável e criação do Secret Kubernetes esperado sem exibir seu conteúdo
- [ ] 4.4 Validar o comportamento de falha com origem ou identidade inválida e restaurar a configuração, verificando condição de erro útil e ausência de valores sensíveis em eventos e logs coletados

## 5. Aplicação Java e Helm

- [ ] 5.1 Modernizar o build de `demo-java-app` e seu Dockerfile multi-stage com versões fixadas, verificando testes Maven, criação da imagem e importação nos nodes K3D
- [ ] 5.2 Consolidar `helm/app` com Deployment, Service, Ingress, health checks e referências apenas às chaves necessárias do Secret, verificando `helm lint`, renderização e ausência de valores do OpenBao
- [ ] 5.3 Implantar a imagem versionada de `demo-java-app` e validar rollout e respostas dos probes sem revelar segredos
- [ ] 5.4 Definir o hostname `demo-java-app.localhost` e validar o roteamento Traefik através da porta publicada pelo K3D

## 6. Bootstrap GitOps

- [ ] 6.1 Adaptar a estrutura app-of-apps para separar plataforma e `demo-java-app`, verificando que todos os caminhos do repositório integrado existem e renderizam recursos válidos
- [ ] 6.2 Criar AppProject e Application `demo-java-app-dev` com destino e permissões restritos, verificando que o Argo CD aceita os recursos e não reporta destino ou fonte inválidos
- [ ] 6.3 Criar a Application raiz com ordem de sincronização apropriada para stores, segredos e workload, verificando que a primeira sincronização conclui em `Synced` e `Healthy`
- [ ] 6.4 Habilitar prune e self-heal somente para recursos gerenciados e testar um desvio não sensível, verificando que o Argo CD detecta e restaura o estado Git sem afetar os dados persistentes do OpenBao

## 7. Validação integrada

- [ ] 7.1 Adaptar as verificações estáticas para Compose, K3D, código Java, manifests e charts integrados, verificando sucesso no estado válido e falha diante de um fixture inválido
- [ ] 7.2 Criar um smoke test sem exposição de valores que valide cluster, releases, OpenBao, `SecretStore`, `ExternalSecret`, Secret, Argo CD, rollout Java e HTTP, verificando uma execução completa bem-sucedida
- [ ] 7.3 Recriar o ambiente integrado a partir das instruções e do estado publicado, verificando idempotência do segundo bootstrap e registrando quaisquer passos manuais inevitáveis
- [ ] 7.4 Atualizar a documentação integrada com arquitetura, fronteiras de responsabilidade e diagnóstico de falhas comuns, verificando que os fluxos de build, bootstrap, primeiro deploy, rotação e rollback correspondem aos comandos finais
