#requires -Version 7.0
# Port-forward dos Services (mesmas portas do compose). Ctrl+C encerra.
$forwards = @(
    @{ Svc = 'users-api'; Map = '5001:80' }, @{ Svc = 'catalog-api'; Map = '5002:80' },
    @{ Svc = 'payments-api'; Map = '5003:80' }, @{ Svc = 'notifications-api'; Map = '5004:80' },
    @{ Svc = 'rabbitmq'; Map = '15672:15672' }, @{ Svc = 'jaeger'; Map = '16686:16686' }
)
$procs = foreach ($f in $forwards) {
    Write-Host "  http://localhost:$($f.Map.Split(':')[0])  →  svc/$($f.Svc)"
    Start-Process kubectl -ArgumentList '-n', 'fcg', 'port-forward', "svc/$($f.Svc)", $f.Map -NoNewWindow -PassThru
}
Write-Host '(Ctrl+C para encerrar)'
try { Wait-Process -Id $procs.Id } finally { $procs | Stop-Process -ErrorAction SilentlyContinue }
