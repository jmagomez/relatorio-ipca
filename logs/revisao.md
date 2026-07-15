# Revisão do Boletim Macro Semanal — referência 2026-07-13

Documento revisado: `boletim.qmd`
Fonte de dados conferida: `output/dados/resumo.csv`
Regras conferidas: `CLAUDE.MD`

## Checklist

1. **Números batem com resumo.csv**
   - IPCA: valor_atual 0,16 (06/2026), var_mes 0,16, var_ano 3,36, var_12m 4,64 — todos reproduzidos corretamente no quadro e no texto de "Inflação".
   - Câmbio: valor_atual 5,12 (07/2026), var_mes 0,70, var_ano -6,98, var_12m -8,15 — todos reproduzidos corretamente no quadro e no texto de "Câmbio e juros".
   - Selic meta: valor_atual 14,25 (07/2026), var_mes -0,25, var_ano -0,75, var_12m -0,75 — todos reproduzidos corretamente.
   - IBC-Br: valor_atual 113,73 (04/2026), var_mes 0,51, var_ano 6,01, var_12m 0,92 — todos reproduzidos corretamente.
   - Nenhuma divergência numérica encontrada.

2. **Unidades corretas**
   - Selic expressa em "p.p." e "p.p. a.a." (não em pontos-base) — correto.
   - Câmbio em "%" para variações e "R$" para o nível — correto.
   - IPCA em "%" — correto.
   - IBC-Br em nível ("índice") e variações em "%" — correto.

3. **IBC-Br com identificação das duas séries**
   - var_mes atribuída à série com ajuste sazonal, SGS 24364, citada explicitamente no quadro e no corpo do texto ("Na comparação mensal, a série com ajuste sazonal (fonte: Banco Central, SGS 24364)...").
   - var_ano e var_12m atribuídas à série original, SGS 24363, citada explicitamente no quadro e no texto ("a série original (fonte: Banco Central, SGS 24363)...").
   - Atribuição consistente com a convenção definida em CLAUDE.MD (var_mes da SA; var_ano e var_12m da original).

4. **Tratamento de NA**
   - A função `fmt()`/`fmt_data()` retorna "indicador indisponível nesta semana" para valores NA/NULL, conforme a regra do CLAUDE.MD ("NA → 'indicador indisponível nesta semana'").
   - Não há nenhum indicador com NA em `resumo.csv` nesta semana, portanto o caminho de fallback não é exercido no HTML atual, mas o código está corretamente implementado caso ocorra.
   - Nenhum "NA" literal é impresso em nenhum ponto do documento (todo valor passa por `fmt()`/`fmt_data()`).

5. **Coerência (alta x valor negativo)**
   - O texto não emprega adjetivos de direção (ex.: "alta", "queda", "avanço", "recuo"); todas as menções usam a formulação neutra "variação de X%/p.p.", inclusive para os valores negativos (câmbio -6,98%/-8,15%; Selic -0,25/-0,75 p.p.).
   - Não há contradição entre qualificação textual e sinal do valor.

6. **Estilo (vícios do CLAUDE.md)**
   - Regra "falha por série, não global" respeitada: `extrai()` degrada para NA por indicador sem interromper o restante do boletim.
   - Fontes SGS citadas com os números de série corretos (433, 1, 432, 24363, 24364), como no CLAUDE.MD.
   - Não há hedging, meta-comentário ou frases de preenchimento (ex.: "é importante notar", "vale ressaltar"); a prosa é direta e técnica.

7. **Tom descritivo, sem previsão**
   - Todas as frases descrevem valores já observados ("registrou", "está cotada em", "está em", "tem nível de", "apresenta variação de"), sem verbos ou construções prospectivas (ex.: "deve", "tende a", "espera-se").
   - Nenhuma projeção ou recomendação é feita.

## Observação não bloqueante

- O quadro-resumo (seção "Quadro") não inclui uma coluna "Var. ano"; esse dado aparece apenas no corpo do texto de cada seção. Isso não constitui erro nem divergência — é uma opção de layout —, mas fica registrado como sugestão de melhoria futura (adicionar coluna "Var. ano" ao quadro, se desejado).

## Veredito

ok
