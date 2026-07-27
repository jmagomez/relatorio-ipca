ok

# Revisão do Boletim Macro Semanal — referência 2026-07-27

## Itens verificados

1. **Números vs. resumo.csv**: todos os valores exibidos em `boletim.qmd` são
   gerados dinamicamente via `extrai()`/`fmt()` a partir de
   `output/dados/resumo.csv` (sem valores numéricos hardcoded no texto). Os
   nomes de indicador usados no código (`IPCA`, `Cambio R$/US$`, `Selic meta`,
   `IBC-Br`) e as colunas (`valor_atual`, `data_ref`, `var_mes`, `var_ano`,
   `var_12m`) correspondem exatamente ao cabeçalho e ao conteúdo do CSV
   (IPCA 0,16/0,16/3,36/4,64; Câmbio 5,07/-2,75/-7,92/-8,28; Selic
   14,25/0,00/-0,75/-0,75; IBC-Br 109,53/0,07/2,20/0,80). Nenhuma divergência
   encontrada.

2. **Unidades**: Selic exibida consistentemente em "p.p." e "p.p. a.a."
   (nunca em pontos-base/bps); câmbio com prefixo "R$ " no nível e "%" nas
   variações; IPCA em "%". Compatível com a coluna `unidade` do CSV.

3. **IBC-Br**: quadro-resumo e seção "Atividade" citam explicitamente as duas
   séries com identificação de fonte — SA/SGS 24364 para `var_mes` e
   original/SGS 24363 para `var_ano` e `var_12m` — de acordo com a convenção
   do CLAUDE.MD.

4. **Tratamento de NA**: a função `fmt()`/`fmt_data()` retorna
   "indicador indisponível nesta semana" para `NA`/`NULL`, atendendo à regra
   do CLAUDE.MD. (Nesta rodada o CSV não contém NA, mas o mecanismo está
   correto e por indicador, não falha global.)

5. **Coerência de sinal**: o câmbio tem `var_mes` = -2,75% nesta semana. O
   texto usa apenas linguagem neutra ("a variação é de X%"), sem palavras
   como "alta", "subiu" ou "avançou" associadas a esse valor negativo (nem em
   nenhum outro indicador). Nenhum trecho descreve valor negativo como alta.

6. **Estilo**: segue as convenções do CLAUDE.MD (fontes via `rbcb::get_series`,
   identificação de séries SGS, convenção IBC-Br, falha por série).

7. **Tom**: descritivo em todo o documento, sem verbos ou expressões de
   previsão/tendência futura.

8. **Data de referência**: 2026-07-27 aparece corretamente no YAML
   (`subtitle`), na variável `data_ref_boletim`, no corpo ("Quadro" e
   rodapé). Não há resquícios de 2026-07-20 no arquivo.

Nenhuma inconsistência encontrada.
