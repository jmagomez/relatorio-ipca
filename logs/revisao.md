ok

Revisão do boletim.qmd (data de referência 2026-09-28) contra output/dados/resumo.csv.

1. Números — todos os valores lidos via `extrai()`/`fmt()` no quadro e no texto
   corrido batem, célula a célula, com `output/dados/resumo.csv`:
   - IPCA: valor_atual -0,32 (data_ref 2026-08-01), var_mes -0,32, var_ano 3,11,
     var_12m 4,22.
   - Cambio R$/US$: valor_atual 5,21 (data_ref 2026-09-28), var_mes 0,24,
     var_ano -5,26, var_12m -2,46.
   - Selic meta: valor_atual 13,75 (data_ref 2026-09-28), var_mes -0,25,
     var_ano -1,25, var_12m -1,25.
   - IBC-Br: valor_atual 114,40 (data_ref 2026-07-01), var_mes -0,22,
     var_ano 1,50, var_12m 1,48.
   Reconferi ainda câmbio e Selic contra as séries brutas
   (`output/dados/cambio.csv` e `output/dados/selic.csv`):
   câmbio em 28/09/2026 = 5,2132 (arredonda para 5,21); var_mes vs. 28/08/2026
   (5,2005) = +0,24%; var_ano vs. 31/12/2025 (5,5024) = -5,26%; var_12m vs.
   26/09/2025 (5,3445) = -2,46% — todos batem. Selic: 13,75 (28/09) - 14,00
   (28/08) = -0,25 p.p.; 13,75 - 15,00 (31/12/2025) = -1,25 p.p.; 13,75 - 15,00
   (28/09/2025) = -1,25 p.p. — todos batem. Nenhuma divergência numérica.

2. Unidades — Selic sempre em p.p. (nunca pontos-base); nível em "% a.a.". O
   texto reforça isso explicitamente ("as variações abaixo são reportadas em
   pontos percentuais (p.p.), nunca em pontos-base").

3. Câmbio — aparece como "R\$/US\$", com os dois cifrões (escapados), tanto no
   quadro quanto no texto corrido (linhas 101, 150, 209-210); os valores de
   nível usam o prefixo "R\$ " (linhas 107, 151). Correto.

4. IBC-Br — cita a série original (SGS 24363: valor_atual, var_ano, var_12m) e
   a série com ajuste sazonal (SGS 24364: var_mes), identificando a fonte em
   cada menção, tanto no quadro quanto no texto.

5. NA — `fmt()`, `fmt_data()` e `fmt_data_dia()` retornam uniformemente
   "indicador indisponível nesta semana" para NA/NULL; nenhum "NA" cru chega ao
   HTML. Não há NA nos dados desta semana, mas o tratamento está implementado
   e ativo em todos os pontos onde um número é impresso.

6. Coerência — todas as leituras de sinal conferem com o texto: IPCA var_mes
   negativo é descrito como "deflação... e não alta"; câmbio var_mes positivo é
   "subiu" (depreciação), e var_ano/var_12m negativos são "recuo"
   (valorização); Selic negativa nos três horizontes é sempre "recuo"; IBC-Br
   var_mes negativo é "recuo", var_ano/var_12m positivos são "positivo"/"alta".
   Não encontrei nenhuma contradição entre o sinal do número e o verbo/adjetivo
   usado.

7. Estilo — não encontrei nenhum dos vícios registrados no CLAUDE.md: não há
   menção à meta de inflação como ano-calendário nem à formulação antiga de
   "dois trimestres consecutivos" (o boletim, aliás, não trata de meta de
   inflação); o IPCA não é somado de forma simples (o boletim só lê valores já
   calculados em resumo.csv); e o IBC-Br não compara nível contra nível fora do
   ajuste sazonal — var_ano/var_12m são explicitamente descritos como
   "por média de período" sobre a série original.

8. Tom — o texto é descritivo em toda a extensão, relatando o que já ocorreu
   (variações passadas, níveis correntes), sem afirmar o que vai acontecer.
   Observação não bloqueante: a frase "Os três horizontes apontam, portanto,
   na mesma direção: ciclo de corte de juros em curso" (seção Selic) é uma
   leitura um pouco além da simples enumeração dos três números. Não chega a
   ser previsão (não afirma nada sobre decisões futuras do Copom), mas, se o
   time quiser um texto ainda mais conservador, sugiro substituir por algo como
   "os três horizontes analisados apontam na mesma direção: recuo da meta em
   todos eles". Isso não impede o "ok".

9. _quarto.yml — a linha `from: markdown-tex_math_dollars` permanece presente
   (linha 15) e o YAML do boletim.qmd (linhas 1-12) não redeclara `from:`.
   Confirmado.

Nenhuma divergência numérica encontrada; os demais oito critérios são
atendidos, com uma única sugestão estilística opcional no item 8.
