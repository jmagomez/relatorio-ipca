ok

Revisão de boletim.qmd (referência 2026-10-12) contra output/dados/resumo.csv. Nenhuma divergência numérica e nenhuma correção pendente. Conferência feita sobre a fonte; o documento não foi renderizado.

Correções do parecer anterior: crase aplicada (linha 107) e verbos de direção escolhidos pelo sinal, com frases próprias para NA. As funções indisp, dir_txt, mov_txt e sentido_comum estão corretas. IPCA recalculado a partir de ipca.csv: 3,95% no ano e 4,58% em 12 meses, iguais ao resumo. O `_quarto.yml` mantém `from: markdown-tex_math_dollars` e o YAML do boletim não redeclara `from:`.

Observações não bloqueantes:
- O `_quarto.yml` lista só `relatorio_ipca.qmd` em `project: render`. Um `quarto render` sem argumento deixaria o boletim de fora.
- Uma variação não nula que arredonde para 0,00 sairia como "alta de 0,00%". Não afeta os dados atuais.
- A presença de "R$/US$" no HTML publicado não foi conferida.
