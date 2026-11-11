# ADR-0009 — Projeto único por serviço com camadas por pasta

**Contexto.** Clean Architecture costuma ser ensinada com 4 projetos (Domain, Application, Infrastructure, Api).
Multiplicado por 4 serviços, seriam 16 projetos para ~2.000 linhas de código.

**Decisão.** Um projeto `.csproj` por serviço (mais o de testes), com camadas como pastas/namespaces:
`Domain`, `Application`, `Infrastructure`, `Presentation`.

**Regras mantidas.**
- `Domain` não depende de nada externo (nem EF Core, nem ASP.NET, nem MassTransit).
- Portas para o que é externo e trocável: `ITokenService`, `IPaymentGateway`, `IEmailSender`.

**Regras relaxadas conscientemente.**
- `Application` usa o `DbContext` diretamente: o EF Core já implementa Unit of Work e Repository;
  um repositório genérico por cima só adicionaria indireção.
- `Application` usa `IPublishEndpoint` do MassTransit: o outbox transacional depende dessa integração com o EF;
  abstraí-la esconderia exatamente a garantia que importa.

**Consequências.**
- ➕ Menos cerimônia; cada serviço é pequeno e coeso (o microsserviço já é a fronteira do bounded context).
- ➖ O compilador não impede `Domain` de referenciar `Infrastructure`. Se o serviço crescer: separar em projetos
  ou adicionar testes de arquitetura (NetArchTest/ArchUnitNET).
