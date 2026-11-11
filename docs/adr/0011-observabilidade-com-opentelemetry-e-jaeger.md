# ADR-0011 — Observabilidade com OpenTelemetry e Jaeger

**Contexto.** Uma compra atravessa Catalog → RabbitMQ → Payments → RabbitMQ → Catalog e Notifications.
Sem rastreamento, investigar "por que o pedido ficou Pending?" exige caçar logs em três serviços.
A Aula 06 apresenta os três pilares (logs, métricas, tracing) com OpenTelemetry e Jaeger.

**Decisão.**
- **OpenTelemetry** em todos os serviços (`Infrastructure/Observability/ObservabilityExtensions.cs`), com
  instrumentação de ASP.NET Core (sem as rotas `/health`), HttpClient, MassTransit (`ActivitySource "MassTransit"`)
  e Npgsql (`ActivitySource "Npgsql"`, emitido pelo próprio driver).
- Exportação **OTLP** para o **Jaeger v2** (all-in-one), ligada só quando `OTEL_EXPORTER_OTLP_ENDPOINT` existe.
- **Correlação nos logs**: `IncludeScopes` no console faz cada linha carregar `TraceId`/`SpanId`, inclusive dentro
  dos consumers — o mesmo `TraceId` que aparece no Jaeger.

O MassTransit propaga o contexto W3C (`traceparent`) nos headers das mensagens, por isso o trace NÃO se parte no broker.

**Detalhe que custaria horas.** O Jaeger v2 escuta em `localhost` por padrão (herança do OpenTelemetry Collector).
Sem `JAEGER_LISTEN_HOST=0.0.0.0`, nenhum outro container consegue enviar traces — e o exportador falha em silêncio.

**Fora do escopo (evolução).** Métricas com Prometheus + Grafana (também apresentados na Aula 06) e logs
centralizados. O SDK já está no projeto: bastaria `.WithMetrics(...)` e um coletor.

**Consequências.**
- ➕ No vídeo: um trace mostra a compra inteira, com o tempo de cada etapa (inclusive o atraso simulado do pagamento).
- ➖ Armazenamento em memória: os traces somem quando o Jaeger reinicia (adequado para desenvolvimento).
