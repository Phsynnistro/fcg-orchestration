# ADR-0005 — JWT RS256 com JWKS

**Contexto.** O UsersAPI emite tokens; Catalog e Payments precisam validá-los.

**Decisão.** Assinatura assimétrica **RS256**. A chave privada (PKCS#8, Base64) existe apenas no Secret do
UsersAPI. O UsersAPI publica `/.well-known/openid-configuration` e `/.well-known/jwks.json`; os demais serviços
configuram `Jwt__MetadataAddress=http://users-api/.well-known/openid-configuration` e o `JwtBearer` baixa e
cacheia a chave pública.

**Alternativa descartada: HS256 com segredo compartilhado.** Mais simples, mas quem *valida* também pode
*emitir*: um serviço comprometido forjaria tokens de Admin. Viola menor privilégio.

**Consequências.**
- ➕ Rotação de chave sem redeploy dos consumidores (novo `kid` é buscado automaticamente).
- ➕ Demonstra comunicação serviço-a-serviço pelo nome do Service do Kubernetes.
- ➖ Dependência de runtime: se o UsersAPI estiver fora na PRIMEIRA validação, o token é rejeitado (401)
  até a próxima tentativa. Depois do primeiro download, a chave fica em cache.
  Mitigação: o download usa um `HttpClient` com o pipeline padrão de resiliência (retry exponencial,
  circuit breaker e timeouts — ADR-0012), e falhas de validação são logadas com o motivo.
- ➖ `RequireHttpsMetadata=false` dentro do cluster. Em produção: TLS ou mTLS (service mesh).
