#requires -Version 7.0
# Versão PowerShell 7 do e2e-flow.sh (Windows). Mesmos fluxos A, B, C e D.
#   pwsh ./scripts/e2e-flow.ps1
param(
    [string]$UsersUrl = $(if ($env:USERS_URL) { $env:USERS_URL } else { 'http://localhost:5001' }),
    [string]$CatalogUrl = $(if ($env:CATALOG_URL) { $env:CATALOG_URL } else { 'http://localhost:5002' }),
    [string]$PaymentsUrl = $(if ($env:PAYMENTS_URL) { $env:PAYMENTS_URL } else { 'http://localhost:5003' }),
    [string]$AdminEmail = 'admin@fcg.local',
    [string]$AdminPassword = 'Admin@12345'
)
$ErrorActionPreference = 'Stop'

function Title($t) { Write-Host "`n━━━ $t ━━━" -ForegroundColor Magenta }
function Step($t)  { Write-Host "`n▶ $t" -ForegroundColor Cyan }
function Ok($t)    { Write-Host "✔ $t" -ForegroundColor Green }
function Fail($t)  { Write-Host "✖ $t" -ForegroundColor Red; exit 1 }

function Invoke-Api([string]$Method, [string]$Url, $Body = $null, [string]$Token = $null, [int]$Expect = 200) {
    $headers = @{}
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $params = @{ Method = $Method; Uri = $Url; Headers = $headers; SkipHttpErrorCheck = $true; StatusCodeVariable = 'status' }
    if ($null -ne $Body) { $params.Body = ($Body | ConvertTo-Json -Depth 5); $params.ContentType = 'application/json' }
    $response = Invoke-RestMethod @params
    if ($status -ne $Expect) { $response | ConvertTo-Json -Depth 6 | Write-Host; Fail "HTTP $status (esperado $Expect)" }
    Ok "HTTP $status"
    return $response
}

function Wait-Order([string]$OrderId, [string]$Token) {
    for ($i = 0; $i -lt 30; $i++) {
        $order = Invoke-RestMethod -Uri "$CatalogUrl/api/orders/$OrderId" -Headers @{ Authorization = "Bearer $Token" }
        if ($order.status -ne 'Pending') { return $order }
        Write-Host "  ... pedido $OrderId ainda Pending"; Start-Sleep -Seconds 1
    }
    Fail "Pedido $OrderId não saiu de Pending em 30s"
}

$email = "jogador.$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())@fcg.local"
$password = 'Senha@123'

Title 'A) FLUXO DE CADASTRO'
Step "POST $UsersUrl/api/users"
Invoke-Api POST "$UsersUrl/api/users" @{ name = 'Jogador Demo'; email = $email; password = $password } -Expect 201 | Format-List
Step 'Senha fraca → 400'
(Invoke-Api POST "$UsersUrl/api/users" @{ name = 'X'; email = 'x@fcg.local'; password = '123' } -Expect 400).errors | Format-List
Step 'Login'
$token = (Invoke-Api POST "$UsersUrl/api/auth/login" @{ email = $email; password = $password }).accessToken
Write-Host "  token: $($token.Substring(0, 40))..."

Title 'B) COMPRA APROVADA'
$games = (Invoke-Api GET "$CatalogUrl/api/games?pageSize=50").items
$games | Format-Table title, price -AutoSize
$cheap = $games | Where-Object price -le 300 | Sort-Object price | Select-Object -First 1
$expensive = $games | Where-Object price -gt 300 | Select-Object -First 1
Step "POST $CatalogUrl/api/orders ($($cheap.title))"
$order = Invoke-Api POST "$CatalogUrl/api/orders" @{ gameId = $cheap.id } $token -Expect 202
$final = Wait-Order $order.id $token
if ($final.status -ne 'Approved') { Fail "Pedido terminou como $($final.status)" }
Ok "Pedido $($order.id) → Approved"
Step 'Biblioteca'
Invoke-Api GET "$CatalogUrl/api/library" -Token $token | Format-Table title, genre, acquiredAt
Step 'Pagamento'
Invoke-Api GET "$PaymentsUrl/api/payments/orders/$($order.id)" -Token $token | Format-List

Title 'C) COMPRA RECUSADA (preço acima do limite simulado de R$ 300)'
$catalog = Invoke-Api GET "$CatalogUrl/api/games?pageSize=50"
$expensive = $catalog.items | Where-Object price -gt 300 | Select-Object -First 1

if (-not $expensive) {
    Step 'Nenhum jogo acima de R$ 300 no catálogo: o Admin cadastra um para forçar a recusa'
    $adminToken = (Invoke-Api POST "$UsersUrl/api/auth/login" @{ email = $AdminEmail; password = $AdminPassword }).accessToken
    $premium = @{
        title       = "Jogo Premium $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
        description = 'Criado no e2e para o fluxo Rejected'
        genre       = 'RPG'
        price       = 349.90
    }
    $expensive = Invoke-Api POST "$CatalogUrl/api/games" $premium $adminToken -Expect 201
}

Step "POST $CatalogUrl/api/orders  (jogo: $($expensive.title))"
$rejected = Invoke-Api POST "$CatalogUrl/api/orders" @{ gameId = $expensive.id } $token -Expect 202

Step 'Aguardando PaymentsAPI recusar e CatalogAPI consumir PaymentProcessedEvent(Rejected)'
$final = Wait-Order $rejected.id $token
if ($final.status -ne 'Rejected') { Fail "Pedido terminou como $($final.status) (esperado Rejected)" }
$final | Format-List status, rejectionReason | Out-String | Write-Host

Step "GET $CatalogUrl/api/library  (o jogo recusado NÃO pode estar nela)"
$library = Invoke-Api GET "$CatalogUrl/api/library" -Token $token
$items = if ($null -ne $library -and $library.PSObject.Properties.Name -contains 'items') { $library.items } else { $library }
if ($items | Where-Object title -eq $expensive.title) { Fail 'O jogo recusado apareceu na biblioteca' }
Ok "Pedido $($rejected.id) → Rejected; jogo ausente da biblioteca"
Write-Host "  → Confira no log do NotificationsAPI: nenhum e-mail de confirmação para o pedido $($rejected.id)"

Title 'D) REGRAS E AUTORIZAÇÃO'
Step 'Compra duplicada → 409'
(Invoke-Api POST "$CatalogUrl/api/orders" @{ gameId = $cheap.id } $token -Expect 409).detail
$game = @{ title = "Jogo Demo $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"; description = 'Criado no e2e'; genre = 'Indie'; price = 29.90 }
Step 'Usuário comum cadastra jogo → 403'
Invoke-Api POST "$CatalogUrl/api/games" $game $token -Expect 403 | Out-Null
Step 'Admin cadastra jogo → 201'
$adminToken = (Invoke-Api POST "$UsersUrl/api/auth/login" @{ email = $AdminEmail; password = $AdminPassword }).accessToken
Invoke-Api POST "$CatalogUrl/api/games" $game $adminToken -Expect 201 | Format-List id, title, price

Title 'CONCLUÍDO'
Write-Host 'Trace da compra no Jaeger: http://localhost:16686 (Service catalog-api, Operation POST /api/orders)'
Write-Host 'E-mails simulados: docker compose logs notifications-api   |   kubectl -n fcg logs -l app.kubernetes.io/name=notifications-api --tail=80'
