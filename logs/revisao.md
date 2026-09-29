ok

Notas não bloqueantes (nenhuma exige correção):

- Legenda do gráfico de câmbio (chunk grafico-cambio, fig-cap) traz "R$/US$" sem escape. Sai correto porque o _quarto.yml mantém `from: markdown-tex_math_dollars`. Se essa linha for removida, a legenda quebra. O uso escapado no restante do texto e no quadro é o mais seguro.
- A frase "compatível com ciclo de corte de juros" (seção Selic) é caracterização do recuo já observado, não previsão. Pode ser mantida.
- selic.csv tem uma linha de 2026-09-29, posterior à data de referência. O resumo usa apenas dados até 2026-09-28, então não afeta os números.
