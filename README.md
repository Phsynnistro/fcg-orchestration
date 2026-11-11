# FIAP Cloud Games — Orquestração (Tech Challenge Fase 2)

Repositório de **infraestrutura e orquestração** da FCG. Ele sobe a aplicação completa com Docker Compose,
faz o deploy no Kubernetes local e concentra a documentação de arquitetura.

> 📐 Arquitetura: [`docs/arquitetura.md`](docs/arquitetura.md) · Decisões: [`docs/adr`](docs/adr) ·
> Requisitos × implementação: [`docs/matriz-requisitos.md`](docs/matriz-requisitos.md) ·
> Conceitos do curso × código: [`docs/mapa-do-curso.md`](docs/mapa-do-curso.md) · Vídeo: [`docs/roteiro-video.md`](docs/roteiro-video.md)

## Os 5 repositórios

| Repositório | Papel | Porta local |
|---|---|---|
| **fcg-orchestration** (este) | docker-compose, ambiente Kubernetes completo, scripts, documentação | — |
| [fcg-users-api](https://github.com/Phsynnistro/fcg-users-api) | Cadastro, login (JWT RS256), autorização · publica `UserCreatedEvent` | 5001 |
| [fcg-catalog-api](https://github.com/Phsynnistro/fcg-catalog-api) | CRUD de jogos, compra, biblioteca · publica `OrderPlacedEvent`, consome `PaymentProcessedEvent` | 5002 |
| [fcg-payments-api](https://github.com/Phsynnistro/fcg-payments-api) | Pagamento simulado · consome `OrderPlacedEvent`, publica `PaymentProcessedEvent` | 5003 |
| [fcg-notifications-api](https://github.com/Phsynnistro/fcg-notifications-api) | E-mails simulados · consome `UserCreatedEvent` e `PaymentProcessedEvent` | 5004 |

**Os repositórios precisam estar lado a lado** (o compose e os scripts usam caminhos relativos):

```
fcg/
├── fcg-orchestration/        ← você está aqui
├── fcg-users-api/
├── fcg-catalog-api/
├── fcg-payments-api/
└── fcg-notifications-api/
```

```bash
mkdir fcg && cd fcg
git clone https://github.com/Phsynnistro/fcg-orchestration.git
GITHUB_OWNER=Phsynnistro ./fcg-orchestration/scripts/clone-repos.sh
```

## Pré-requisitos

| Ferramenta | Para quê |
|---|---|
| Docker Desktop (ou Docker Engine + Compose v2) | containers e build das imagens |
| Um cluster local: **Kind**, Minikube ou Kubernetes do Docker Desktop | deploy K8s |
| `kubectl` | aplicar manifestos |
| `curl` + `jq` (bash) **ou** PowerShell 7 (Windows) | scripts de teste ponta a ponta |
| .NET SDK 10 (opcional) | rodar/depurar um serviço com `dotnet run` |

No Windows, rode os `.sh` pelo **Git Bash/WSL** ou use as versões `.ps1` com `pwsh`.

## 1. Executar com Docker Compose

```bash
cd fcg-orchestration
docker compose up -d --build      # ou: docker-compose up -d --build
docker compose ps                 # aguarde todos "running"/"healthy"
```

Não é preciso `.env`: o compose traz defaults de **desenvolvimento**. Para sobrescrever algum valor,
`cp .env.example .env` e edite.

| O quê | Endereço |
|---|---|
| UsersAPI (Scalar/OpenAPI) | http://localhost:5001/scalar |
| CatalogAPI | http://localhost:5002/scalar |
| PaymentsAPI | http://localhost:5003/scalar |
| NotificationsAPI (health) | http://localhost:5004/health |
| RabbitMQ Management | http://localhost:15672 (`fcg` / `fcg_dev_pwd`) |
| **Jaeger (traces)** | http://localhost:16686 |

Encerrar: `docker compose down` · Zerar os dados: `docker compose down -v`

## 2. Testar os fluxos

```bash
./scripts/e2e-flow.sh             # bash (curl + jq)
pwsh ./scripts/e2e-flow.ps1       # Windows / PowerShell 7
```

O script executa e valida: **(A)** cadastro → e-mail de boas-vindas; **(B)** compra aprovada → biblioteca + e-mail;
**(C)** compra recusada (jogo acima do limite simulado de R$ 300); **(D)** compra duplicada (409) e autorização por
papel (403 para usuário comum, 201 para Admin). Para demonstração manual: [`requests/fcg.http`](requests/fcg.http).

- E-mails simulados: `docker compose logs -f notifications-api`
- Trace da compra: Jaeger → Service `catalog-api` → Operation `POST /api/orders`
- Administrador criado no startup: `admin@fcg.local` / `Admin@12345`

## 3. Deploy no Kubernetes local

### 3.1 Criar o cluster (escolha um)

```bash
kind create cluster --config cluster/kind-config.yaml     # Kind → contexto kind-fcg
minikube start --memory=6g --cpus=4                       # Minikube
# Docker Desktop → Settings › Kubernetes › Enable Kubernetes
```

### 3.2 Imagens no cluster

O cluster local precisa enxergar as imagens `fcg/*:1.0.0`:

```bash
for s in users catalog payments notifications; do docker build -t fcg/$s-api:1.0.0 ../fcg-$s-api; done
# Kind:     for s in users catalog payments notifications; do kind load docker-image fcg/$s-api:1.0.0 --name fcg; done
# Minikube: for s in users catalog payments notifications; do minikube image load fcg/$s-api:1.0.0; done
# Docker Desktop: nada a fazer (mesmo daemon Docker)
```

### 3.3 Deploy — o comando do desafio

```bash
cd k8s
kubectl apply -f .
kubectl -n fcg get pods
```

A pasta `k8s/` contém o **ambiente completo** (padrão "repositório de ambiente", [ADR-0013](docs/adr/0013-repositorio-de-ambiente.md)).
O prefixo numérico define a ordem de aplicação:

| Prefixo | Conteúdo |
|---|---|
| `00` | Namespace `fcg` |
| `10–14` | RabbitMQ: ConfigMap (arquivo de conf), Secret, PVC, Deployment, Service |
| `15–16` | Jaeger: Deployment, Service |
| `20`/`30`/`40`/`50` | Users / Catalog / Payments / Notifications: ConfigMap, Secrets, banco (PVC + Deployment + Service), Deployment, Service, HPA |

Resultado esperado: 4 APIs × 2 réplicas (mínimo do HPA), 3 PostgreSQL, RabbitMQ e Jaeger — todos `Running`.

Atalho que faz build, carga das imagens, apply e espera os rollouts: `./scripts/k8s-deploy.sh` (ou `pwsh ./scripts/k8s-deploy.ps1`).

### 3.4 Acessar e testar no cluster

```bash
./scripts/k8s-port-forward.sh      # mesmas portas do compose (5001–5004, 15672, 16686)
./scripts/e2e-flow.sh              # em outro terminal
kubectl -n fcg logs -l app.kubernetes.io/name=notifications-api --tail=80
```

### 3.5 HPA com métricas reais (opcional)

```bash
./scripts/k8s-install-metrics-server.sh
kubectl -n fcg get hpa             # TARGETS passa de <unknown> para a % de CPU
```

Remover tudo (inclusive volumes): `./scripts/k8s-destroy.sh`

## 4. Manifestos: onde editar

A **fonte da verdade** de cada serviço é o `/k8s` do **próprio repositório** (requisito do desafio). Depois de
alterar um manifesto lá, sincronize o ambiente:

```bash
./scripts/k8s-sync-manifests.sh            # copia para k8s/ com o prefixo certo
./scripts/k8s-sync-manifests.sh --check    # o CI (validate.yml) roda isto e falha se houver divergência
```

Comunicação no cluster sempre pelo **nome do Service**: `rabbitmq:5672`, `catalog-db:5432`,
`http://users-api:80/.well-known/jwks.json`, `http://jaeger:4317`.

## 5. Antes de entregar: migrations do EF Core

Os serviços aplicam `Migrate()` quando o projeto tem migrations e caem para `EnsureCreated()` quando não tem
(atalho de estudo). Gere as migrations iniciais e versione-as:

```bash
dotnet tool install --global dotnet-ef --version 10.0.13

# a partir da raiz de cada repositório (repita para catalog e payments trocando o nome)
cd ../fcg-users-api
dotnet ef migrations add InitialCreate \
  --project src/Fcg.Users.Api --startup-project src/Fcg.Users.Api \
  --output-dir Infrastructure/Persistence/Migrations
```

O `dotnet ef` executa o `Program.cs` até o `builder.Build()` em ambiente `Development`, por isso a connection string
de `appsettings.Development.json` precisa existir (ela existe).

> Bancos já criados por `EnsureCreated` não têm o histórico de migrations: depois de gerá-las, recrie os volumes
> (`docker compose down -v`; no K8s, `./scripts/k8s-destroy.sh`).

## 6. Segurança das imagens

```bash
./scripts/scan-images.sh           # Trivy: CRITICAL/HIGH com correção disponível
```

O mesmo scan roda no CI de cada serviço e falha o pipeline se encontrar algo corrigível.

## 7. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `ErrImagePull` / `ImagePullBackOff` | imagem não carregada no cluster | seção 3.2 (`kind load` / `minikube image load`) |
| Pod de API em `CrashLoopBackOff` | banco ainda subindo ou Secret errado | `kubectl -n fcg logs deploy/<svc>`; a API tenta 10× antes de desistir |
| `namespaces "fcg" not found` ao aplicar um repositório isolado | — | cada `/k8s` de serviço já traz `00-namespace.yaml`; aplique a pasta inteira (`kubectl apply -f .`) |
| 401 nas primeiras chamadas ao Catalog/Payments | UsersAPI ainda não estava Ready para entregar o JWKS | aguarde; o log mostra `Token rejeitado: <motivo>` |
| Nenhum trace no Jaeger | serviço sem `OTEL_EXPORTER_OTLP_ENDPOINT` ou Jaeger sem `JAEGER_LISTEN_HOST=0.0.0.0` | confira ConfigMap/compose (ADR-0011) |
| 429 Too Many Requests no login | rate limit (20/min por IP) | aguarde a janela ou ajuste `RateLimiting__Authentication__*` |
| `bad interpreter: /bin/bash^M` | script com CRLF (Windows) | o `.gitattributes` já força LF; reclone ou `git add --renormalize .` |
| `kubectl get hpa` mostra `<unknown>` | metrics-server ausente | seção 3.5 (o mínimo de 2 réplicas vale mesmo assim) |

## 8. Estrutura deste repositório

```
fcg-orchestration/
├── docker-compose.yml        ambiente completo (4 APIs + RabbitMQ + 3 PostgreSQL + Jaeger)
├── .env.example              sobrescritas opcionais (o compose já tem defaults)
├── rabbitmq/20-fcg.conf      configuração do broker (mesmo conteúdo do ConfigMap)
├── k8s/                      AMBIENTE completo: kubectl apply -f .
├── cluster/kind-config.yaml  definição do cluster Kind
├── scripts/                  deploy, sync de manifestos, port-forward, metrics-server, e2e, Trivy, chaves
├── requests/fcg.http         requisições para VS / VS Code / Rider
├── .github/workflows/        validação do compose e da sincronia dos manifestos
└── docs/                     arquitetura, ADRs, matriz de requisitos, mapa do curso, roteiro, relatório
```
