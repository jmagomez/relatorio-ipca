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
$repoUrl  = "https://packagemanager.posit.co/cran/latest"

# Calcular arvore recursiva de dependencias (exclui base e recommended do R)
$depScript = @"
pkgs <- c('rbcb','sidrar','dplyr','lubridate','slider','forcats',
          'ggplot2','scales','knitr','rmarkdown','httr','jsonlite','stringr')
db   <- utils::installed.packages()
deps <- tools::package_dependencies(pkgs, db=db, recursive=TRUE,
          which=c('Imports','Depends','LinkingTo'))
todos    <- unique(c(pkgs, unlist(deps, use.names=FALSE)))
base_rec <- rownames(db[!is.na(db[,'Priority']) &
             db[,'Priority'] %in% c('base','recommended'),])
contrib  <- sort(setdiff(todos, c(base_rec, NA)))
for (p in contrib) {
  v <- tryCatch(packageDescription(p, fields='Version'), error=function(e) NA_character_)
  if (!is.na(v)) cat(p, '|', v, '\n')
}
"@
$enc = New-Object System.Text.UTF8Encoding $false
$tmpDep = [System.IO.Path]::GetTempFileName() + ".R"
[System.IO.File]::WriteAllText($tmpDep, $depScript, $enc)
$depOutput = & $rscript --no-save $tmpDep 2>$null
Remove-Item $tmpDep -ErrorAction SilentlyContinue

$pkgLines = foreach ($line in ($depOutput -split "`n" | Where-Object { $_ -match '\|' })) {
    $parts = $line.Trim() -split '\s*\|\s*', 2
    $p = $parts[0].Trim(); $v = $parts[1].Trim()
    "    `"$p`": { `"Source`": `"CRAN`", `"Repository`": `"$repoUrl`", `"description`": { `"Package`": `"$p`", `"Version`": `"$v`", `"Source`": `"CRAN`" } }"
}
$packagesJson = ($pkgLines | Where-Object { $_ }) -join ",`n"

# Arquivos: fontes Quarto + HTML pre-renderizado + assets
$sourceFiles = @("relatorio_ipca.qmd","_quarto.yml",
                 "R/coleta.R","R/tratamento.R","R/graficos.R")
$staticFiles = @("relatorio_ipca.html") + @(
    Get-ChildItem -Recurse -File "relatorio_ipca_files" |
    ForEach-Object { $_.FullName.Replace("$PSScriptRoot\","").Replace("\","/") }
)
$filesLines = ($sourceFiles + $staticFiles) | Where-Object { Test-Path $_ } | ForEach-Object {
    $path = $_.Replace("\","/")
    $hash = (Get-FileHash $_ -Algorithm MD5).Hash.ToLower()
    "    `"$path`": { `"checksum`": `"$hash`" }"
}
$filesJson = $filesLines -join ",`n"

$manifest = "{`n" +
    "  `"version`": 1,`n" +
    "  `"locale`": `"en_US`",`n" +
    "  `"platform`": `"$rVersion`",`n" +
    "  `"metadata`": {`n" +
    "    `"appmode`": `"quarto-static`",`n" +
    "    `"primary_rmd`": null,`n" +
    "    `"primary_html`": `"relatorio_ipca.html`",`n" +
    "    `"has_parameters`": false`n" +
    "  },`n" +
    "  `"packages`": {`n" +
    $packagesJson + "`n" +
    "  },`n" +
    "  `"files`": {`n" +
    $filesJson + "`n" +
    "  },`n" +
    "  `"users`": null`n" +
    "}"

# UTF-8 sem BOM — Posit Connect rejeita BOM no JSON
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot "manifest.json"), $manifest, $utf8NoBom)

Write-Host "$($filesLines.Count) arquivos | $(@($pkgLines | Where-Object {$_}).Count) pacotes" -ForegroundColor Green

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
