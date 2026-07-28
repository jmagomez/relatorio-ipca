ok

# Revisão do Boletim Macro Semanal — referência 2026-07-28

## Itens verificados

1. **Números vs. resumo.csv**: todos os valores exibidos em `boletim.qmd`
   (texto e quadro) são gerados dinamicamente via `extrai()`/`fmt()`/`fmt_data()`
   a partir de `output/dados/resumo.csv`, sem valores hardcoded. Conferência
   linha a linha:
   - IPCA: valor_atual 0,16% (06/2026); var_mes 0,16%; var_ano 3,36%;
     var_12m 4,64% — batem com o CSV e com texto/quadro.
   - Câmbio R$/US$: valor_atual R$ 5,10 (data_ref 27/07/2026, legítima —
     último fechamento disponível, distinta da data de referência do
     boletim); var_mes -1,33%; var_ano -7,30%; var_12m -8,72% — batem com
     o CSV e com texto/quadro (inclusive o var_12m, que mudou em relação a
     rodadas anteriores e está refletido corretamente por vir do CSV, não
     de valor fixo no código).
   - Selic meta: valor_atual 14,25 p.p. a.a. (07/2026); var_mes 0,00 p.p.;
     var_ano -0,75 p.p.; var_12m -0,75 p.p. — batem com o CSV.
   - IBC-Br: valor_atual 109,53 (índice, 05/2026); var_mes 0,07%;
     var_ano 2,20%; var_12m 0,80% — batem com o CSV.
   Nenhuma divergência numérica encontrada.

2. **Unidades**: Selic sempre em "p.p." / "p.p. a.a." (nunca bps); câmbio
   com prefixo "R$ " nos valores de nível e "%" nas variações; IPCA em "%";
   IBC-Br em "(índice)" no nível e "%" nas variações. Compatível com a
   coluna `unidade` do CSV.

3. **Convenção IBC-Br**: `var_mes` usa a série com ajuste sazonal
   (SGS 24364), citada explicitamente no quadro ("% (SA, SGS 24364)") e no
   corpo ("série com ajuste sazonal ... SGS 24364"); `var_ano` e `var_12m`
   usam a série original (SGS 24363), citada no quadro ("% (original,
   SGS 24363)") e no corpo ("série original ... SGS 24363"). Conforme
   CLAUDE.MD.

4. **Tratamento de NA**: `fmt()`/`fmt_data()` retornam "indicador
   indisponível nesta semana" para NA/NULL, por indicador (a função
   `extrai()` já isola cada indicador com NAs próprios em caso de ausência
   no CSV, sem derrubar o boletim inteiro). Nesta rodada o CSV não contém
   NA, mas o mecanismo está correto.

5. **Coerência de sinal**: câmbio tem var_mes/var_ano/var_12m todos
   negativos (-1,33% / -7,30% / -8,72%); Selic tem var_ano/var_12m
   negativos (-0,75 p.p.). Em nenhum trecho esses valores são descritos
   como "alta" — o texto usa linguagem neutra ("a variação é de X%"/"foi
   de X p.p."). Nenhuma incoerência de sinal encontrada.

6. **Data de referência (2026-07-28)**: aparece corretamente no YAML
   (`subtitle: "Data de referência: 2026-07-28"`), na variável
   `data_ref_boletim <- "2026-07-28"`, no corpo ("Data de referência do
   boletim: 2026-07-28") e no rodapé ("dados disponíveis em 2026-07-28").
   Não há resquícios de 2026-07-13/20/27 como data de referência do
   boletim. A data 2026-07-27 aparece apenas como `data_ref` legítima do
   indicador câmbio (vindo do CSV), o que é esperado e não constitui
   resquício.

7. **Unidade do câmbio R$/US$ e escape de cifrão**:
   - `_quarto.yml` mantém `from: markdown-tex_math_dollars`, desligando a
     leitura de `$...$` como fórmula matemática.
   - O YAML de `boletim.qmd` não redeclara `from:` (bloco `format: html:`
     contém apenas `theme`, `toc`, `toc-depth`, `number-sections`,
     `self-contained`), preservando a proteção do `_quarto.yml`.
   - `boletim.qmd` usa cifrão escapado (`R\$/US\$` no texto corrido e
     `"R\\$ "`/`"Câmbio R\\$/US\\$"` dentro das strings de R, que produzem
     literalmente `R\$/US\$` e `R\$ ` como texto markdown). Como o escape
     de pontuação com backslash (`\$` → `$`) é uma regra do markdown do
     Pandoc independente da extensão `tex_math_dollars` estar ligada ou
     desligada, o resultado renderizado é sempre "R$/US$" (dois cifrões,
     texto e quadro) e "R$ " (valores), de forma correta e consistente em
     todas as ocorrências do arquivo. É redundante frente à proteção já
     dada pelo `_quarto.yml` (bastaria escrever `$` sem barra), mas não é
     incorreto nem gera divergência — não há necessidade de alteração.
   - Nota à parte (fora do escopo de edição): o `boletim.html` atualmente
     commitado no repositório, referente à rodada 2026-07-27, mostra
     "R\<span class="math inline">\(/US\)</span>" quebrado. Conforme
     contexto fornecido, trata-se de artefato antigo, anterior ao fix do
     cifrão, e não reflete o `boletim.qmd`/`_quarto.yml` atuais — não é
     motivo de reprovação desta rodada, mas fica registrado para que o
     HTML seja re-renderizado na publicação.

8. **Estilo**: segue as convenções do CLAUDE.MD — fontes citadas via
   SGS com número da série, `rbcb::get_series` mencionado no rodapé,
   convenção IBC-Br respeitada, falha por série (via `extrai()`),
   mensagem padrão de indisponibilidade. Nenhum vício de estilo
   identificado (sem jargão redundante, sem repetição indevida de
   qualificadores).

9. **Tom**: descritivo em todo o documento. Não há verbos/expressões de
   previsão ou tendência futura (não aparecem "deve", "vai", "tende a",
   "projeta-se" ou equivalentes).

Nenhuma inconsistência numérica, de unidade, de convenção ou de tom
encontrada. Aprovado.
