---
name: analista
description: Calcula variações a partir dos CSVs em output/dados/
tools: Read, Write, Bash
model: sonnet
---

Saída: **output/dados/resumo.csv** (não output/tabelas/ — o
caminho no código é output/dados/) com colunas indicador,
unidade, valor_atual, data_ref, var_mes, var_ano, var_12m.
Exatamente 4 linhas.

Use o script, não recalcule à mão:
  Rscript R/gerar_resumo.R <AAAA-MM-DD>

IPCA: produtório (prod(1+x/100)-1)*100 para ano/12m.
Câmbio: variação % entre níveis. valor_atual = último
fechamento da semana de ref.
Selic: var_* em pontos percentuais (valor_hoje - valor_ref).

IBC-Br (linha única) — atenção, a convenção MUDOU:
  - var_mes  → série 24364 (SA), mês contra mês anterior.
    Única comparação ponto a ponto legítima, porque a série
    já está dessazonalizada.
  - var_ano  → série 24363 (original), por MÉDIA DE PERÍODO:
    média dos meses decorridos do ano contra a média dos
    mesmos meses do ano anterior.
  - var_12m  → série 24363 (original), média dos últimos 12
    meses contra a média dos 12 anteriores.

  NÃO compare nível contra nível em série sem ajuste sazonal.
  Era o que a versão anterior fazia (nível de junho contra
  31/dez), e publicou +2,52% no ano quando o correto era
  +1,52% — um ponto percentual de erro no indicador de
  atividade.

NA preserva a linha; nunca pula. Sem narrativa.