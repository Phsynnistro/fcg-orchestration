#requires -Version 7.0
# Versão PowerShell 7 do k8s-deploy.sh (Windows).   pwsh ./scripts/k8s-deploy.ps1 [-SkipBuild]
param([switch]$SkipBuild, [string]$Tag = '1.0.0')
$ErrorActionPreference = 'Stop'

$orch = Resolve-Path (Join-Path $PSScriptRoot '..')
$root = Resolve-Path (Join-Path $orch '..')
$services = 'users-api', 'catalog-api', 'payments-api', 'notifications-api'
function Step($t) { Write-Host "`n▶ $t" -ForegroundColor Cyan }
function Run { & $args[0] $args[1..($args.Length - 1)]; if ($LASTEXITCODE -ne 0) { throw "Falhou: $args" } }

$context = (kubectl config current-context).Trim()
Step "Contexto: $context"

if (-not $SkipBuild) {
    foreach ($svc in $services) {
        $repo = Join-Path $root "fcg-$svc"
        if (-not (Test-Path $repo)) { throw "Repositório fcg-$svc não encontrado ao lado de fcg-orchestration." }
        Step "Build fcg/${svc}:$Tag"
        Run docker build -t "fcg/${svc}:$Tag" $repo
        if ($context -like 'kind-*') { Run kind load docker-image "fcg/${svc}:$Tag" --name $context.Substring(5) }
        elseif ($context -eq 'minikube') { Run minikube image load "fcg/${svc}:$Tag" }
    }
}

Step 'kubectl apply -f .  (pasta k8s)'
Push-Location (Join-Path $orch 'k8s'); try { Run kubectl apply -f . } finally { Pop-Location }

Step 'Aguardando os rollouts'
foreach ($dep in 'rabbitmq', 'jaeger', 'users-db', 'catalog-db', 'payments-db', 'users-api', 'catalog-api', 'payments-api', 'notifications-api') {
    Run kubectl -n fcg rollout status "deployment/$dep" --timeout=300s
}
kubectl -n fcg get deploy,pods,svc,hpa
Write-Host "`n✅ Próximos passos: pwsh ./scripts/k8s-port-forward.ps1  e  pwsh ./scripts/e2e-flow.ps1" -ForegroundColor Green
