# update_manifest.ps1
# Atualiza manifest.json apos novo render do relatorio.
#
# Uso:
#   .\update_manifest.ps1              # so atualiza manifest + stage
#   .\update_manifest.ps1 -Render      # renderiza o QMD antes
#   .\update_manifest.ps1 -Render -Push  # renderiza, atualiza e faz commit+push

param(
    [switch]$Render,
    [switch]$Push,
    [string]$CommitMsg = ""
)

Set-Location $PSScriptRoot

# ── 1. Renderizar ──────────────────────────────────────────────────────────────
if ($Render) {
    Write-Host "Renderizando relatorio_ipca.qmd..." -ForegroundColor Cyan
    quarto render relatorio_ipca.qmd --no-freeze
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Render falhou." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK" -ForegroundColor Green
}

# ── 2. Gerar manifest.json ─────────────────────────────────────────────────────
Write-Host "Gerando manifest.json..." -ForegroundColor Cyan

$rscript  = "C:\Program Files\R\R-4.6.0\bin\Rscript.exe"
$rVersion = & $rscript --no-save -e "cat(as.character(getRversion()))" 2>$null

# Apenas os arquivos necessarios para servir o HTML estatico
$deployFiles = @("relatorio_ipca.html") + @(
    Get-ChildItem -Recurse -File "relatorio_ipca_files" |
    ForEach-Object { $_.FullName.Replace("$PSScriptRoot\", "").Replace("\", "/") }
)

$filesLines = $deployFiles | Where-Object { Test-Path $_ } | ForEach-Object {
    $hash = (Get-FileHash $_ -Algorithm MD5).Hash.ToLower()
    $path = $_.Replace("\", "/")
    "    `"$path`": { `"checksum`": `"$hash`" }"
}
$filesJson = $filesLines -join ",`n"

$manifest = "{`n" +
    "  `"version`": 1,`n" +
    "  `"locale`": `"en_US`",`n" +
    "  `"platform`": `"$rVersion`",`n" +
    "  `"metadata`": {`n" +
    "    `"appmode`": `"static`",`n" +
    "    `"primary_rmd`": null,`n" +
    "    `"primary_html`": `"relatorio_ipca.html`",`n" +
    "    `"has_parameters`": false`n" +
    "  },`n" +
    "  `"packages`": null,`n" +
    "  `"files`": {`n" +
    $filesJson + "`n" +
    "  },`n" +
    "  `"users`": null`n" +
    "}"

# UTF-8 sem BOM (Posit Connect rejeita BOM no JSON)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText(
    (Join-Path $PSScriptRoot "manifest.json"),
    $manifest,
    $utf8NoBom
)

Write-Host "$($filesLines.Count) arquivos no manifest (HTML + assets)" -ForegroundColor Green

# ── 3. Stage ───────────────────────────────────────────────────────────────────
Write-Host "Adicionando arquivos ao stage..." -ForegroundColor Cyan
git add relatorio_ipca.html relatorio_ipca_files/ manifest.json 2>$null
git status --short

# ── 4. Commit + Push (opcional) ────────────────────────────────────────────────
if ($Push) {
    $mes = Get-Date -Format "MM/yyyy"
    if ($CommitMsg -eq "") {
        $CommitMsg = "Atualiza relatorio IPCA - $mes"
    }

    Write-Host "Commitando: $CommitMsg" -ForegroundColor Cyan
    git commit -m $CommitMsg
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Nada para commitar ou erro no commit." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Fazendo push..." -ForegroundColor Cyan
    git push
    Write-Host "Deploy disponivel em breve no Posit Connect / GitHub Pages" -ForegroundColor Green

} else {
    $mes = Get-Date -Format "MM/yyyy"
    Write-Host ""
    Write-Host "Proximo passo:" -ForegroundColor Yellow
    Write-Host "  git commit -m `"Atualiza relatorio IPCA - $mes`""
    Write-Host "  git push"
}
