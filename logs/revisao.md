ok

# Revisão do Boletim Macro Semanal — referência 2026-07-27

## Itens verificados

1. **Números vs. resumo.csv**: todos os valores exibidos em `boletim.qmd` são
   gerados dinamicamente via `extrai()`/`fmt()` a partir de
   `output/dados/resumo.csv` (sem valores numéricos hardcoded no texto). Os
   nomes de indicador usados no código (`IPCA`, `Cambio R$/US$`, `Selic meta`,
   `IBC-Br`) e as colunas (`valor_atual`, `data_ref`, `var_mes`, `var_ano`,
   `var_12m`) correspondem exatamente ao cabeçalho e ao conteúdo do CSV desta
   rodada: IPCA 0,16/06-2026/0,16/3,36/4,64; Câmbio 5,10/27-07-2026/-1,33/
   -7,30/-7,98; Selic 14,25/27-07-2026/0,00/-0,75/-0,75; IBC-Br 109,53/
   05-2026/0,07/2,20/0,80. Nenhuma divergência encontrada entre o texto/quadro
   e o CSV (inclusive os valores de câmbio, que mudaram em relação à rodada
   anterior — 5,07/-2,75%/-7,92%/-8,28% — e estão corretamente refletidos
   agora como 5,10/-1,33%/-7,30%/-7,98%, sem resquício dos valores antigos).

2. **Unidades**: Selic exibida consistentemente em "p.p." e "p.p. a.a."
   (nunca em pontos-base/bps); câmbio com prefixo "R$ " no nível e "%" nas
   variações; IPCA em "%"; IBC-Br em "(índice)" no nível e "%" nas variações.
   Compatível com a coluna `unidade` do CSV.

3. **IBC-Br**: quadro-resumo e seção "Atividade" citam explicitamente as duas
   séries com identificação de fonte — SA/SGS 24364 para `var_mes` e
   original/SGS 24363 para `var_ano` e `var_12m` — de acordo com a convenção
   do CLAUDE.MD.

4. **Tratamento de NA**: a função `fmt()`/`fmt_data()` retorna
   "indicador indisponível nesta semana" para `NA`/`NULL`, atendendo à regra
   do CLAUDE.MD. (Nesta rodada o CSV não contém NA, mas o mecanismo está
   correto e degrada por indicador, não globalmente.)

5. **Coerência de sinal**: o câmbio tem `var_mes` = -1,33%, `var_ano` = -7,30%
   e `var_12m` = -7,98% nesta semana (todos negativos). O texto usa apenas
   linguagem neutra ("a variação é de X%"), sem palavras como "alta", "subiu"
   ou "avançou" associadas a esses valores negativos, nem em nenhum outro
   indicador. Nenhum trecho descreve valor negativo como alta.

6. **Estilo**: segue as convenções do CLAUDE.MD (fontes via `rbcb::get_series`,
   identificação de séries SGS, convenção IBC-Br, falha por série, mensagem
   padrão de indisponibilidade).

7. **Tom**: descritivo em todo o documento, sem verbos ou expressões de
   previsão/tendência futura (ex.: "deve", "tende a", "projeta-se" não
   aparecem).

8. **Data de referência**: 2026-07-27 aparece corretamente no YAML
   (`subtitle`), na variável `data_ref_boletim`, no corpo ("Quadro") e no
   rodapé. Não há resquícios de datas de rodadas anteriores (2026-07-13 ou
   2026-07-20) no arquivo.

Nenhuma inconsistência encontrada.
