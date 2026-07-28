# Boletim Macro Semanal

## Fontes (todas via rbcb::get_series)
- IPCA mensal: SGS 433
- Câmbio R$/US$: SGS 1
- Selic meta: SGS 432
- IBC-Br original: SGS 24363
- IBC-Br com ajuste sazonal: SGS 24364

## Convenção IBC-Br
- var_mes da série SA (24364)
- var_ano e var_12m da série original (24363)

## Unidade do câmbio: R$/US$
- O Pandoc lê o trecho entre dois `$` como fórmula matemática,
  o que publicava `R$/US$` como "R/US"
- `_quarto.yml` desliga a extensão (`from: markdown-tex_math_dollars`),
  então o cifrão é sempre literal e o boletim.qmd pode escrever
  `R$/US$` direto
- Essa linha é a única proteção que sobrevive à regeneração semanal
  do boletim.qmd pelo redator — não remova, e não redeclare `from:`
  no YAML do boletim.qmd

## Regras
- Falha por série, não global
- NA → "indicador indisponível nesta semana"
- Publicador só roda com revisao.md = "ok"
