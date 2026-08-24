ok

Parecer da revisão — boletim.qmd (data de referência 2026-08-24)

Todos os pontos do checklist foram conferidos e não há divergências.

1. Números batem com output/dados/resumo.csv, campo a campo:
   - IPCA: valor_atual/var_mes 0,07% (data_ref 2026-07-01), var_ano 3,44%,
     var_12m 4,44% — ok, tanto no quadro quanto no texto.
   - Câmbio: valor_atual R$ 5,16 (data_ref 2026-08-21, arredondamento correto
     de 5,1625), var_mes +1,66%, var_ano -6,18%, var_12m -5,84% — ok.
   - Selic: valor_atual 14,00% a.a. (data_ref 2026-08-24), var_mes -0,25 p.p.,
     var_ano -1,00 p.p., var_12m -1,00 p.p. — ok.
   - IBC-Br: valor_atual 109,89 (data_ref 2026-06-01), var_mes -0,64%
     (SA, SGS 24364), var_ano 2,52% e var_12m 2,35% (original, SGS 24363) — ok.

2. Selic sempre em % a.a. para o nível e p.p. para as variações; o texto só
   menciona "pontos-base" para dizer explicitamente que essa NÃO é a unidade
   usada. Corte de 0,25 p.p. do nível 14,00% a.a. é coerente com var_mes do
   CSV.

3. Câmbio grafado como "R$/US$" (dois cifrões, via "R\$/US\$" escapado no R)
   tanto no quadro quanto no texto corrido e no rodapé, e valores numéricos
   sempre com prefixo "R$ " (ex.: "R$ 5,16"). Nenhuma ocorrência de "R/US" ou
   cifrão simples. A chave de lookup extrai("Cambio R$/US$") permanece crua
   (sem escape) de propósito, para casar com a coluna `indicador` do CSV —
   conferido que isso não vaza para o HTML (só é usado internamente).

4. IBC-Br cita as duas séries com identificação de fonte e código SGS em
   todas as ocorrências: var_mes atribuída à série com ajuste sazonal
   (SGS 24364) e var_ano/var_12m à série original (SGS 24363), conforme
   convenção do CLAUDE.MD.
   - Ponto sensível desta rodada: a data_ref do IBC-Br mudou de 2026-05-01
     (rodada anterior) para 2026-06-01. O texto afirma corretamente
     "Trata-se de observação nova em relação à rodada anterior" — não há
     resíduo do "não houve observação nova" da semana passada.
   - Coerência de sinal: var_mes (SA) é -0,64% e o texto usa "recuo na
     margem" — não sobrou nenhuma narrativa de alta herdada da rodada
     anterior (que tinha var_mes +0,07%). O texto também sintetiza
     corretamente: "a série dessazonalizada recua na margem mensal enquanto
     a série original permanece em patamar superior ao do mesmo período do
     ano anterior", batendo com var_12m positivo (2,35%) e var_ano positivo
     (2,52%).

5. Não há valores NA nesta rodada, mas fmt()/fmt_data() implementam
   corretamente a mensagem "indicador indisponível nesta semana" (contém o
   texto "indicador indisponível" exigido) para NULL/NA, garantindo
   degradação segura caso falte algum indicador.

6. Coerência sinal x narrativa — ponto mais sensível desta rodada:
   - Câmbio: var_mes é positivo (+1,66%) e o texto usa "subiu" e
     "desvalorização do Real no período mensal" — direção correta (dólar
     sobe = Real desvaloriza). var_ano/var_12m são negativos e o texto usa
     "recuo" com abs() e conclui "valorização do Real" nesses horizontes —
     direção correta (dólar cai = Real valoriza). O texto ainda explicita
     que os sinais mensal e anual/12m são opostos nesta rodada, evitando
     qualquer leitura ambígua.
   - Selic: variações negativas tratadas com "corte" e abs() onde a palavra
     já indica a direção — coerente.
   - IBC-Br: ver item 4 acima — coerente.

7. Estilo: sem vícios identificados (linguagem direta, sem jargão
   desnecessário, sem redundância problemática; as frases de síntese sobre
   sinais opostos são explicações objetivas, não floreios).

8. Tom estritamente descritivo em todo o documento (verbos como "registrou",
   "está em", "apresenta", "recua", "tem nível"), sem linguagem de
   previsão/expectativa (não há "deve", "tende a", "espera-se" etc.).

9. _quarto.yml mantém a linha `from: markdown-tex_math_dollars` (linha 15,
   comentada como proteção que não deve ser removida), e o cabeçalho YAML de
   boletim.qmd (linhas 1-12) não redeclara `from:`.
