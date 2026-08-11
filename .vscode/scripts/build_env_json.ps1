# build_env_json.ps1
# Gera .env.json a partir do .env para uso com --dart-define-from-file
# (formato exigido pelo Flutter: JSON plano chave -> valor string)
$root   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) # .vscode/scripts -> raiz do repo
$envFile  = Join-Path $root ".env"
$jsonOut  = Join-Path $root ".env.json"

if (-not (Test-Path $envFile)) {
    Write-Error "Arquivo .env nao encontrado em $envFile. Copie .env.example para .env e preencha."
    exit 1
}

$map = @{}
Get-Content $envFile | Where-Object { $_ -match "^[^#].+=.+" } | ForEach-Object {
    $parts = $_ -split "=", 2
    $map[$parts[0].Trim()] = $parts[1].Trim()
}

if ($map.Count -eq 0) {
    Write-Error "Nenhuma variavel encontrada em .env."
    exit 1
}

$json = $map | ConvertTo-Json
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($jsonOut, $json, $utf8NoBom)

Write-Host ".env.json gerado com $($map.Count) variaveis em $jsonOut"