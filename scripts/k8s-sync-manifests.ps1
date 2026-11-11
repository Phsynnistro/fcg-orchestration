#requires -Version 7.0
# Versão PowerShell do k8s-sync-manifests.sh: copia os manifestos dos serviços para k8s/ (repositório de ambiente).
param([switch]$Check)
$orch = Resolve-Path (Join-Path $PSScriptRoot '..'); $root = Resolve-Path (Join-Path $orch '..')
$prefix = [ordered]@{ 'users-api' = '20'; 'catalog-api' = '30'; 'payments-api' = '40'; 'notifications-api' = '50' }
$expected = @{}
foreach ($svc in $prefix.Keys) {
    Get-ChildItem (Join-Path $root "fcg-$svc/k8s") -Filter *.yaml | Where-Object Name -ne '00-namespace.yaml' |
        ForEach-Object { $expected["$($prefix[$svc])-$svc-$($_.Name)"] = $_.FullName }
}
$target = Join-Path $orch 'k8s'
if ($Check) {
    $diff = foreach ($name in $expected.Keys) {
        $dest = Join-Path $target $name
        if (-not (Test-Path $dest) -or (Get-FileHash $dest).Hash -ne (Get-FileHash $expected[$name]).Hash) { "divergente: $name" }
    }
    if ($diff) { $diff; exit 1 } else { 'manifestos sincronizados'; exit 0 }
}
Get-ChildItem $target -Filter '[2-5]0-*-api-*.yaml' | Remove-Item
foreach ($name in $expected.Keys) { Copy-Item $expected[$name] (Join-Path $target $name) }
"$($expected.Count) manifestos copiados para k8s/"
