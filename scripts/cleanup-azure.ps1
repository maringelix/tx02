# cleanup-azure.ps1 - Script para limpar recursos Azure

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

Write-Host "⚠️  ATENÇÃO: Este script irá DESTRUIR todos os recursos no Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host ""

if (-not $Force) {
    $confirmation = Read-Host "Digite 'YES' para confirmar a destruição"
    if ($confirmation -ne 'YES') {
        Write-Host "❌ Operação cancelada." -ForegroundColor Red
        exit 1
    }
}

Write-Host "🔍 Listando recursos no Resource Group..." -ForegroundColor Cyan
az resource list --resource-group $ResourceGroup --output table

Write-Host ""
Write-Host "🗑️  Removendo Resource Group e todos os recursos..." -ForegroundColor Red
az group delete --name $ResourceGroup --yes --no-wait

Write-Host "✅ Comando de remoção iniciado (operação assíncrona)" -ForegroundColor Green
Write-Host "📊 Para verificar o progresso:" -ForegroundColor Cyan
Write-Host "   az group show --name $ResourceGroup" -ForegroundColor Gray
Write-Host ""
Write-Host "⏱️  A remoção completa pode levar 10-15 minutos." -ForegroundColor Yellow
