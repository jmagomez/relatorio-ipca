ok

Verificação do ciclo de correção 1 (referência 2026-09-28):

- Números: todos os valores do quadro e do texto batem com output/dados/resumo.csv (IPCA -0,32 / 3,11 / 4,22; câmbio 5,21 / 0,24 / -5,26 / -2,46; Selic 13,75 / -0,25 / -1,25 / -1,25; IBC-Br 114,40 / -0,22 / 1,50 / 1,48). Folga de 0,28 p.p. até o teto confere (4,50 - 4,22).
- Câmbio no boletim.html: "R$/US$" aparece corretamente no quadro, no texto da seção de câmbio, na legenda do gráfico de câmbio e no rodapé; valor com prefixo "R$ 5,21". Não há `\(` nem `\)` em nenhum trecho de texto do corpo do HTML.
- Limite da checagem no HTML: a tag <img> de cada gráfico fica numa linha com PNG em base64 grande demais para leitura. Não pude inspecionar atributos como alt nessas quatro linhas (2268, 2285, 2299, 2317). As legendas (figcaption) estão corretas.
- Unidades: Selic em p.p., sem pontos-base.
- IBC-Br cita as duas séries (24364 SA na margem, 24363 original em 12 meses e no ano).
- Nenhum NA impresso; nenhum indicador indisponível nesta semana.
- Coerência: câmbio "subiu" no mês (+0,24) e "recuo" no ano e em 12 meses (negativos); IPCA mensal negativo descrito como variação, não como alta.
- Tom descritivo, sem previsão. "compatível com ciclo de corte de juros" descreve o recuo já observado.
- _quarto.yml mantém `from: markdown-tex_math_dollars`; o YAML do boletim.qmd não redeclara `from:`.

Notas não bloqueantes:

- "Há 0 mês(es) consecutivo(s) fora da banda" é redação pouco natural para o caso zero. Sugestão: "Não há meses consecutivos fora da banda".
- O bloco `project: render:` do _quarto.yml lista só relatorio_ipca.qmd. Isso não afeta a renderização direta do boletim.qmd, mas um `quarto render` sem argumento não o incluiria.
- O CLAUDE.MD não traz uma lista explícita de vícios de estilo. Conferi o texto contra as convenções que ele define (meta contínua, p.p., R$/US$).
