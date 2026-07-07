# run_web.ps1 - Roda o KordApp no Chrome com as variaveis de ambiente do .env
$envFile = ".\.env"

if (-not (Test-Path $envFile)) {
    Write-Error "Arquivo .env nao encontrado! Copie .env.example para .env e preencha."
    exit 1
}

$env_vars = @{}
Get-Content $envFile | Where-Object { $_ -match "^[^#].+=.+" } | ForEach-Object {
    $parts = $_ -split "=", 2
    $env_vars[$parts[0].Trim()] = $parts[1].Trim()
}

$dartDefines = ($env_vars.GetEnumerator() | ForEach-Object {
    "--dart-define=""$($_.Key)=$($_.Value)"""
}) -join " "

$cmd = "flutter run -d chrome $dartDefines"
Write-Host "Iniciando KordApp no Chrome..." -ForegroundColor Cyan
Invoke-Expression $cmd