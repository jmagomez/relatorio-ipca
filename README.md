# Relatório IPCA

Relatório mensal automatizado da inflação brasileira (IPCA), produzido com **Quarto** e publicável via Posit Connect Cloud.

## Fontes de dados

| Série | Fonte | Conteúdo |
|---|---|---|
| 433 | BCB via `rbcb` | Variação mensal do IPCA |
| 13521 | BCB via `rbcb` | Meta de inflação (anual) |
| Tabela 7060 | SIDRA/IBGE via `sidrar` | IPCA por grupos de despesa |

## Estrutura

```
R/
  coleta.R        # Coleta via API (rbcb, sidrar)
  tratamento.R    # Transformações puras (acumulados, sazonalidade, contribuições)
  graficos.R      # Funções ggplot2 + salvar_graficos()
relatorio_ipca.qmd   # Documento Quarto
_quarto.yml          # Configuração do projeto (tema, TOC, freeze)
```

## Pré-requisitos

```r
install.packages(c(
  "rbcb", "sidrar", "slider",
  "dplyr", "tidyr", "lubridate",
  "ggplot2", "scales"
))
```

[Quarto 1.3+](https://quarto.org/docs/get-started/)

## Como renderizar

```bash
quarto render relatorio_ipca.qmd
```

Gera `relatorio_ipca.html` (autocontido) na raiz. Os gráficos PNG ficam em `output/`.

Para forçar reexecução completa sem cache:

```bash
quarto render relatorio_ipca.qmd --no-freeze
```

## Atualização mensal

O mecanismo `freeze: auto` reprocessa apenas os chunks cujo código foi alterado.
Para incorporar novos dados do mês, basta renderizar — as funções de coleta consultam as APIs em tempo real.
