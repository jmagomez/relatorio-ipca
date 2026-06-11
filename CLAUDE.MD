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

## Regras
- Falha por série, não global
- NA → "indicador indisponível nesta semana"
- Publicador só roda com revisao.md = "ok"