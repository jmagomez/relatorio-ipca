ok

Revisão do boletim de 2026-11-16. Sem divergência numérica e sem pendência bloqueante.

Conferências
- Item 1, números: resumo.csv bate com o texto e com o quadro (IPCA 0,14% / 4,10% / 4,63%; câmbio 5,73, 12,78% / 4,18% / 8,26%; Selic 13,75, 0,00 / -1,25 / -1,25 p.p.; IBC-Br 109,43, -0,25% / 1,39% / 1,43%). Recalculei a partir de cambio.csv e ibcbr.csv: 5,7324 / 5,0826 (base 16/10/2026) = +12,78%; 5,5007 / 5,0377 = +9,19% (23/10 a 26/10/2026); IBC-Br original set/2026 = 109,42914. O salto de 9,19% é o único de 4% ou mais depois da base de 16/10 (27/10 foi -3,02%; a queda de 05/10 fica antes da base e fora da janela).
- Item 2, unidades: Selic só em p.p., sem pontos-base.
- Item 3, câmbio: R$/US$ com dois cifrões no texto, no quadro, no rodapé e nos fig-cap (escapados como R\\$/US\\$ em YAML entre aspas). Valores com prefixo "R$ ".
- Item 4, IBC-Br: valor do quadro agora traz "(índice, original, SGS 24363)", a var. mensal traz "(SA, SGS 24364)" e a de 12 meses "(original, SGS 24363)". O texto cita 24364 para a margem e 24363 para ano e 12 meses. Correção 1 da revisão anterior aplicada.
- Item 5, NA: fmt, fmt_data, fmt_data_dia e os textos condicionais devolvem "indicador indisponível nesta semana". Você reportou nenhum "NA" no HTML.
- Item 6, coerência: IBC-Br SA negativo sai como "queda"; câmbio positivo como "subiu" e "desvalorização"; Selic com 0,00 no mês e -1,25 nos demais sai como estável no mês e recuo nos outros horizontes.
- Item 7, estilo: o CLAUDE.MD não traz lista de vícios de estilo, e não encontrei jargão nem adjetivação indevida. A frase "grande parte da alta mensal" foi removida (correção 2 aplicada). Não verifiquei .claude/agents/.
- Item 8, tom: descritivo, sem previsão. O texto diz expressamente que a causa do câmbio não é atribuída.
- Item 9, _quarto.yml: `from: markdown-tex_math_dollars` presente (linha 15). O YAML do boletim.qmd não redeclara `from:`.

Observações sem bloqueio
- project.render no _quarto.yml lista só relatorio_ipca.qmd. O boletim herda a configuração apenas se for renderizado pelo nome (quarto render boletim.qmd), o que já vale hoje.
- Não executei o R nem o render. O texto final do HTML foi conferido pelo trecho que você colou, e os números foram recalculados a partir dos CSVs.
