# ADR-0006 — Event-carried state transfer para notificações

**Contexto.** O e-mail de confirmação precisa do endereço do usuário e do nome do jogo, mas o
`PaymentProcessedEvent` exigido pelo desafio só traz IDs e status.

**Decisão.** O CatalogAPI inclui `UserEmail` (claim do token) e `GameTitle` no `OrderPlacedEvent`;
o PaymentsAPI os propaga no `PaymentProcessedEvent`. O NotificationsAPI fica stateless.

**Alternativas.**
1. *Notifications chama Users/Catalog por HTTP*: acoplamento temporal — se Users cair, não sai e-mail.
2. *Notifications mantém projeção local* (consome `UserCreatedEvent` e grava e-mail por `UserId`):
   o desenho mais "puro", mas exige banco no Notifications.

**Consequências.**
- ➕ Zero chamadas síncronas; Notifications não precisa de banco.
- ➖ Dado pessoal (e-mail) trafega no broker e passa pelo Payments, que não precisa dele (LGPD: minimização).
- ➖ Payments carrega campos que existem só para outro consumidor.
- **Revisitar** quando o Notifications ganhar banco (o que também resolveria a falta de inbox): migrar para a alternativa 2.
