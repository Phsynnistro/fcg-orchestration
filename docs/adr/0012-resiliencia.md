# ADR-0012 — Resiliência: retry com backoff, circuit breaker e timeouts

**Contexto.** A Aula 05 apresenta circuit breaker, retry com backoff exponencial, fallback e bulkhead.
O sistema tem dois tipos de dependência remota: a chamada HTTP de JWKS (síncrona) e o consumo de mensagens.

**Decisão.**

| Onde | Padrão | Implementação |
|---|---|---|
| Download do JWKS (Catalog, Payments) | timeout por tentativa, retry exponencial com jitter, circuit breaker, timeout total | `AddHttpClient(...).AddStandardResilienceHandler()` (Microsoft.Extensions.Http.Resilience = Polly v8) como `Backchannel` do JwtBearer |
| Consumers (Catalog, Payments, Notifications) | retry com backoff exponencial | `UseMessageRetry(r => r.Exponential(5, ...))`; `DomainException` não é retentada |
| Consumers | circuit breaker | `UseKillSwitch`: com ≥ 15% de falhas (após 10 mensagens), o endpoint para de consumir por 30 s |
| Banco (todos) | retry de falhas transitórias | `EnableRetryOnFailure` do Npgsql (compatível com o outbox — ADR-0003) |
| Mensagem que esgotou as tentativas | dead letter | fila `<fila>_error` criada pelo MassTransit |
| Bulkhead | isolamento de recursos | `ConcurrentMessageLimit`/`PrefetchCount` por fila e `limits` de CPU/memória por pod |

**Por que o kill switch importa.** Sem ele, com o banco fora do ar, cada mensagem esgotaria o retry e iria para
`_error` — o sistema "queimaria" a fila inteira. Com ele, o consumo pausa e as mensagens esperam na fila.

**Fallback.** Não há fallback de negócio sensato para "não sei validar o token" (seria aceitar sem validar).
O fallback do sistema é estrutural: o outbox mantém os eventos enquanto o broker está fora.

**Consequências.**
- ➕ Falhas transitórias não chegam ao usuário nem geram mensagens perdidas.
- ➖ Retentativas aumentam a latência no pior caso; os limites (5 tentativas, 10 s) são deliberadamente baixos.
