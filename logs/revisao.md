ok

Reconferência completa (checklist 1-9) após as correções do redator:

1. Números: os 16 valores de `valor_atual`, `var_mes`, `var_ano` e `var_12m` dos quatro indicadores continuam batendo exatamente com `output/dados/resumo.csv`, com referência à coluna certa em cada `r fmt(...)`. A extração (`extrai()`) e o data frame `dados` não foram alterados.
2. Selic sempre em p.p., com nota explícita de que nunca é pontos-base — inalterado.
3. Câmbio aparece como "R\$/US\$" (dois cifrões, escapados) no quadro e no texto, e os valores de nível usam prefixo "R\$ " — inalterado.
4. IBC-Br cita as duas séries com identificação: var_mes com SA/SGS 24364; var_ano e var_12m com original/SGS 24363, var_ano explicitamente "por média de período" — inalterado.
5. `fmt_data_dia()`, nova função (linhas 52-60), trata NA/NULL exatamente como `fmt()` e `fmt_data()`: retorna "indicador indisponível nesta semana". Consistente com o restante do boletim.
6. Coerência de sinais integralmente correta, incluindo a Selic (var_mes = -0,25 p.p. tratada como "recuo da meta na comparação mensal", sem resquício de "estabilidade") — texto de coerência não foi tocado nesta rodada.
7. Nenhum vício do CLAUDE.md (meta contínua, trimestre anualizado, soma simples de variações) — o boletim continua sem mencionar esses temas.
8. Tom estritamente descritivo, sem previsão — inalterado.
9. `_quarto.yml` mantém `from: markdown-tex_math_dollars` (linha 15) e o YAML do boletim.qmd não redeclara `from:` — inalterado.

Datas de referência, agora corrigidas:
- IPCA: `fmt_data(ipca$data_ref)` → "08/2026" (ago/2026) — série mensal, sem alteração.
- Câmbio: `fmt_data_dia(cambio$data_ref)` → "18/09/2026", usada no rótulo do quadro (linha 101) e no texto (linha 152) — corrigido conforme apontado.
- Selic: `fmt_data_dia(selic$data_ref)` → "21/09/2026", usada no rótulo do quadro (linha 102, que agora também traz a data, como os demais indicadores) e no texto (linha 166) — corrigido conforme apontado.
- IBC-Br: `fmt_data(ibc$data_ref)` → "07/2026" (jul/2026) — série mensal, sem alteração.

Nenhuma outra alteração foi introduzida além das duas correções relatadas: estrutura das seções, número de indicadores, textos de coerência e rodapé de fontes permanecem idênticos à versão revisada anteriormente.
