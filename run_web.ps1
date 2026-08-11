# run_web.ps1 - Roda o KordApp no Chrome com as variaveis de ambiente do .env
# Usa o mesmo mecanismo do F5 (VS Code): gera .env.json a partir do .env
$root = Split-Path -Parent $MyInvocation.MyCommand.Path # raiz do repo
$jsonOut = Join-Path $root ".env.json"

if (-not (Test-Path $jsonOut)) {
    Write-Host "Gerando .env.json a partir do .env..." -ForegroundColor Cyan
    & (Join-Path $root ".vscode\scripts\build_env_json.ps1")
}

if (-not (Test-Path $jsonOut)) {
    Write-Error "Nao foi possivel gerar .env.json. Verifique se o arquivo .env existe."
    exit 1
}

Write-Host "Iniciando KordApp no Chrome..." -ForegroundColor Cyan
flutter run -d chrome --dart-define-from-file=.env.json