ok

Parecer da revisão — boletim.qmd (data de referência 2026-08-17)

Todos os pontos do checklist foram conferidos e não há divergências.

1. Números batem com output/dados/resumo.csv, campo a campo:
   - IPCA: valor_atual/var_mes 0,07%, var_ano 3,44%, var_12m 4,44% — ok.
   - Câmbio: valor_atual R$ 5,22 (data_ref 2026-08-14), var_mes +2,94%,
     var_ano -5,07%, var_12m -3,44% — ok.
   - Selic: valor_atual 14,00% a.a., var_mes -0,25 p.p., var_ano -1,00 p.p.,
     var_12m -1,00 p.p. — ok.
   - IBC-Br: valor_atual 109,53 (data_ref 2026-05-01), var_mes 0,07%,
     var_ano 2,20%, var_12m 0,80% — ok.

2. Selic sempre em % a.a. para nível e p.p. para variações; nenhuma menção
   a pontos-base como unidade (o texto só cita "pontos-base" para dizer
   explicitamente que NÃO é a unidade usada). O corte de 0,25 p.p. para o
   nível de 14,00% a.a. está correto e coerente (14,25% -> 14,00%).

3. Câmbio grafado como "R$/US$" (dois cifrões) tanto no quadro quanto no
   texto corrido, e valores numéricos sempre com prefixo "R$ " (ex.: "R$
   5,22"). Nenhuma ocorrência de "R/US" ou cifrão simples.

4. IBC-Br cita as duas séries com identificação de fonte e SGS: var_mes
   atribuída à série com ajuste sazonal (SGS 24364) e var_ano/var_12m à
   série original (SGS 24363), conforme convenção do CLAUDE.MD. O texto
   também explicita corretamente que não houve observação nova nesta
   semana (mesma data_ref da rodada anterior, 2026-05-01), sem inferir
   dado novo.

5. Não há valores NA nesta rodada, mas fmt()/fmt_data() implementam
   corretamente a mensagem "indicador indisponível nesta semana" para
   NULL/NA, garantindo degradação segura caso falte algum indicador.

6. Coerência sinal x narrativa, ponto mais sensível desta rodada:
   - Câmbio var_mes é positivo (+2,94%) e o texto usa "subiu" / "alta" /
     "desvalorização do Real no período mensal", revertendo
     explicitamente a narrativa de queda da rodada anterior (não houve
     herança de texto desatualizado).
   - Câmbio var_ano/var_12m são negativos e o texto usa "recuo" /
     "valorização do Real", com abs() aplicado apenas para exibir a
     magnitude ao lado de palavras que já indicam a direção — sinais e
     verbos coerentes, e o texto ainda observa explicitamente que os
     sinais mensal e anual/12m são opostos nesta rodada.
   - Selic: var_mes/var_ano/var_12m negativos, tratados com "corte" e
     valores absolutos onde a palavra já indica a direção; coerente.

7. Estilo: sem vícios identificados (linguagem direta, sem jargão
   excessivo, sem redundância indevida).

8. Tom estritamente descritivo em todo o documento (verbos como
   "registrou", "está em", "apresenta", "não houve observação nova"),
   sem linguagem de previsão/expectativa.

9. _quarto.yml mantém a linha `from: markdown-tex_math_dollars`
   (necessária para "R$/US$" não ser interpretado como fórmula), e o
   cabeçalho YAML de boletim.qmd (linhas 1-12) não redeclara `from:`.
