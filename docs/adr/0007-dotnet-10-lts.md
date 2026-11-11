# ADR-0007 — .NET 10 LTS

**Contexto.** O desafio pede ".NET 8 ou superior".

**Decisão.** .NET 10 (LTS, suportado até novembro de 2028).

**Por quê.** O .NET 8 encerra o suporte em **10/11/2026**. Iniciar um projeto numa versão a semanas do fim do
suporte significa nascer sem patches de segurança. O .NET 10 também traz `Guid.CreateVersion7()` (IDs ordenáveis
no tempo), OpenAPI nativo (`AddOpenApi`/`MapOpenApi`) e imagens chiseled baseadas em Ubuntu 24.04.

**Consequências.**
- ➖ Microsoft.OpenApi 2.x (breaking change em relação aos exemplos antigos de Swashbuckle).
- ➕ Versões de pacotes fixadas via Central Package Management; o `global.json` fixa o SDK 10.0.1xx+.
