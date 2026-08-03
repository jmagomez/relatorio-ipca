ok

Parecer detalhado — rodada de referência 2026-08-03.

Todos os números do boletim.qmd foram conferidos campo a campo contra
output/dados/resumo.csv, e todas as chamadas extrai()/fmt() usam o
indicador, o campo e o sufixo corretos. Nenhuma divergência numérica
encontrada.

1. Números vs. resumo.csv
   - IPCA: valor_atual/var_mes 0,16% (linha "registrou variação de..."),
     var_ano 3,36% ("acumulado do ano"), var_12m 4,64% ("doze meses").
     Quadro replica os mesmos valores. OK.
   - Câmbio: valor_atual 5,08 ("R$ 5,08"), var_mes -1,92%, var_ano -7,73%,
     var_12m -9,37% — todos exibidos via abs() no texto (1,92% / 7,73% /
     9,37%) e com sinal no quadro (-1,92% / -7,73% / -9,37%). Módulo
     confere exatamente com o CSV. OK.
   - Selic: valor_atual 14,25% a.a., var_mes 0,00 p.p., var_ano -0,75 p.p.,
     var_12m -0,75 p.p. — nível e variações batem linha a linha com o CSV.
     OK.
   - IBC-Br: valor_atual 109,53 (índice), var_mes 0,07%, var_ano 2,20%,
     var_12m 0,80% — todos batem com o CSV, e a atribuição de série segue
     a convenção do CLAUDE.MD (var_mes → SA/24364; var_ano e var_12m →
     original/24363). OK.

2. Unidade da Selic — o resumo.csv traz unidade "% a.a." para o nível
   (14,25), e o boletim.qmd usa esse sufixo apenas para valor_atual
   (`fmt(selic$valor_atual, suffix = "% a.a.")`). As três variações usam
   sufixo " p.p." (nunca pontos-base), e o texto explicita a distinção:
   "O nível da taxa é expresso em percentual ao ano (% a.a.); já as
   variações abaixo são reportadas em pontos percentuais (p.p.), nunca em
   pontos-base." Não há mistura entre nível e variação. Correto — é a
   leitura pretendida nesta rodada, não um erro.

3. Câmbio R$/US$ — aparece com os dois cifrões, sempre escapados
   (`R\$/US\$` no texto corrido, `R\\$/US\\$` dentro das strings de R do
   quadro) tanto no corpo do texto quanto no quadro-resumo, e os valores
   monetários usam prefixo "R$ " (`fmt(cambio$valor_atual, prefix =
   "R\\$ ")`). Consistente com a proteção descrita no CLAUDE.MD.

4. Divergência de data do câmbio (data_ref 2026-07-31 vs. data de
   referência do boletim 2026-08-03) é tratada explicitamente no texto
   ("data distinta da data de referência geral deste boletim... por se
   tratar do último fechamento disponível"), condizente com 2026-08-03
   ser segunda-feira. Não é resquício de rodada anterior — é o
   comportamento esperado.

5. IBC-Br — cita as duas séries com identificação de fonte e código SGS
   em todas as ocorrências (série original, SGS 24363, para nível,
   var_ano e var_12m; série com ajuste sazonal, SGS 24364, para var_mes),
   seguindo a convenção do CLAUDE.MD.

6. NA — fmt() e fmt_data() retornam "indicador indisponível nesta semana"
   para NA/NULL; nenhum indicador desta rodada está com NA, mas a lógica
   está correta e cobre o caso.

7. Coerência (alta x valor negativo) — as três variações do câmbio são
   negativas no CSV e o texto usa verbos de queda ("recuou", "queda de",
   "retração de") com o valor absoluto; a conclusão de que "o Real se
   valorizou frente ao dólar" está correta (queda na cotação R$/US$
   implica valorização do Real). Sem contradição entre sinal e narrativa.

8. Estilo — texto descritivo, sem uso de linguagem de previsão/projeção
   (não há "deve", "espera-se", "projeta" etc.); segue as convenções do
   CLAUDE.MD (fontes, séries do IBC-Br, tratamento de NA).

9. _quarto.yml mantém a linha `from: markdown-tex_math_dollars` (linha 15,
   sob format/html), com o comentário de proteção intacto. O YAML do
   boletim.qmd (linhas 1–12) não redeclara `from:` em nenhum nível —
   confere.

Observação não bloqueante: o quadro-resumo exibe a variação do câmbio com
sinal (-1,92% etc.), enquanto o texto corrido usa o valor absoluto
acompanhado de verbo de queda. São representações diferentes do mesmo
número, mas ambas corretas e não conflitantes — trata-se de escolha de
redação coerente, não de erro de magnitude.
