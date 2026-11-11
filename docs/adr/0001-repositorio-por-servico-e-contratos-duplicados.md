# ADR-0001 — Repositório por serviço e contratos duplicados

**Contexto.** O desafio exige um repositório Git por microsserviço. Os serviços trocam eventos, então
precisam concordar sobre o formato das mensagens.

**Decisão.** Cada repositório mantém sua **cópia** dos contratos que publica/consome, no namespace
`Fcg.Contracts.Events` e com `[EntityName]` explícito. Um teste de contrato (`ContractTests`) em cada
repositório falha se namespace, nome ou exchange divergirem.

**Alternativas descartadas.**
- *Pacote NuGet de contratos compartilhado*: exige feed privado (GitHub Packages/Azure Artifacts),
  versionamento e publicação coordenada — e cria acoplamento de build entre repositórios.
- *Biblioteca "chassis" compartilhada* (logging, health, JWT): é o padrão Microservice Chassis e vale a pena
  com 10+ serviços. Com 4, a duplicação de ~10 arquivos de infraestrutura é mais barata que o feed.

**Consequências.**
- ➕ Autonomia total: cada repositório builda, testa e faz deploy sozinho.
- ➖ Contratos podem divergir. Mitigação: evolução **aditiva** apenas (novos campos opcionais), testes de contrato.
- ➖ O MassTransit identifica a mensagem pela URN `urn:message:Fcg.Contracts.Events:<Tipo>`:
  mudar o namespace num único repositório quebra a integração **sem erro de compilação** — por isso o teste.
