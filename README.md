# Relatório Mensal do IPCA

Relatório automatizado em Quarto com análise mensal do IPCA (Índice Nacional de Preços ao Consumidor Amplo), publicado via Posit Connect Cloud.

## Fontes de dados

| Série | Origem | Conteúdo |
|---|---|---|
| 433 | BCB / `rbcb` | IPCA variação mensal |
| 13521 | BCB / `rbcb` | Meta de inflação anual |
| Tabela 7060 | SIDRA/IBGE / `sidrar` | IPCA por grupos de despesa |

## Estrutura do projeto

```
.
├── _quarto.yml            # Configuração do projeto Quarto
├── relatorio_ipca.qmd     # Documento principal
├── R/
│   ├── coleta.R           # Coleta de dados via API
│   ├── tratamento.R       # Transformações e cálculos
│   └── graficos.R         # Visualizações ggplot2
└── output/                # PNGs gerados (não versionados)
```

## Como rodar

### Pré-requisitos

- [R ≥ 4.1](https://cran.r-project.org/)
- [Quarto ≥ 1.4](https://quarto.org/)

### Instalar dependências R

```r
install.packages(c(
  "rbcb", "sidrar",
  "dplyr", "lubridate", "slider", "forcats",
  "ggplot2", "scales",
  "knitr", "rmarkdown"
))
```

### Renderizar o relatório

```bash
quarto render relatorio_ipca.qmd
```

O arquivo `relatorio_ipca.html` será gerado na raiz do projeto e os gráficos em `output/`.

## Atualização mensal

O relatório busca dados diretamente nas APIs do BCB e do IBGE a cada render. Com `freeze: auto` no `_quarto.yml`, o Quarto reexecuta os chunks apenas quando o `.qmd` for modificado. Para forçar atualização dos dados:

```bash
quarto render relatorio_ipca.qmd --no-freeze
```
