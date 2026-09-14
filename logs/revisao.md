ok
Verificação feita a partir de `output/dados/resumo.csv`, `_quarto.yml` e `CLAUDE.MD` (referência 2026-09-14).

Confirmado: a correção pontual na linha 129 ("acumulados positivo" → "acumulados
positivos") foi aplicada e nenhuma outra linha do boletim.qmd ou do _quarto.yml
foi alterada.

Checklist 1–9: números batem com o CSV (IPCA, Câmbio, Selic e IBC-Br conferidos
linha a linha, incluindo `valor_atual`, `var_mes`, `var_ano` e `var_12m`);
Selic sempre em p.p. (nunca "pontos-base"); câmbio aparece como "R$/US$" (dois
cifrões, forma escapada `\$`/`R\\$` no código-fonte, convenção autorizada para
este redator) tanto no texto quanto no quadro, e os valores usam o prefixo
"R$ "; IBC-Br cita as duas séries com identificação de fonte (SA, SGS 24364,
para `var_mes`; original, SGS 24363, para `var_ano`/`var_12m` e para o nível);
NA seria tratado como "indicador indisponível nesta semana" via
`fmt()`/`fmt_data()`; sinais e adjetivos batem com os valores (deflação
mensal do IPCA convivendo com acumulados positivos, recuo do câmbio tratado
como apreciação do Real, recuo da Selic em 12m, sem nenhuma inversão de
"alta"/"queda"); tom é descritivo, sem previsão. Em `_quarto.yml`, a linha
`from: markdown-tex_math_dollars` continua presente; no `boletim.qmd`, a
única ocorrência da string "from:" está dentro de um comentário do chunk de
setup, e o YAML do documento não redeclara `from:`.

Nenhum problema pendente.
