ok

Reavaliação da rodada 2026-08-31 (ciclo 1) — correção aplicada pelo redator confirmada:

- A frase comparativa com a rodada de 2026-08-24 ("Em relação à leitura da
  semana anterior, a desvalorização mensal do Real se intensificou, ao passo
  que a valorização acumulada em doze meses perdeu força.") foi removida da
  seção "Câmbio e juros" > "Taxa de câmbio" e não foi substituída por
  nenhuma outra afirmação comparativa entre rodadas. Buscas por "semana
  anterior", "rodada anterior" e equivalentes no documento não retornam
  ocorrências.
- O parágrafo do câmbio permanece completo e coerente após a remoção: a
  descrição dos sinais opostos continua intacta — var_mes +2,05% (dólar
  sobe → Real desvaloriza) contra var_ano -5,83% e var_12m -4,51%,
  reportados via abs() (dólar cai → Real valoriza) —, com a frase de síntese
  "os sinais das variações mensal e anual/de doze meses seguem opostos
  nesta rodada" mantida.
- Checklist completo (1–9) sem regressões:
  1. Números batem com output/dados/resumo.csv em todas as seções e no
     quadro (IPCA 0,07/3,44/4,44; Câmbio 5,1816→"R$ 5,18"/2,05/-5,83/-4,51;
     Selic 14,00/-0,25/-1,00/-1,00; IBC-Br 109,89/-0,64/2,52/2,35).
  2. Selic reportada em p.p., com nota explícita "nunca em pontos-base".
  3. Câmbio aparece como R$/US$ (dois cifrões, escapados como \$) no texto
     corrido, no quadro e no rodapé de fontes; valores com prefixo "R$ ".
  4. IBC-Br cita as duas séries com identificação de fonte/código: SA
     (SGS 24364) para var_mes e original (SGS 24363) para var_ano/var_12m.
  5. fmt()/fmt_data() tratam NA/NULL como "indicador indisponível nesta
     semana"; nenhuma célula ou trecho imprime "NA".
  6. Coerência mantida: sinais do câmbio interpretados corretamente (alta do
     dólar = desvalorização do Real; recuo do dólar = valorização do Real);
     corte da Selic condizente com var_mes negativo; recuo do IBC-Br SA
     condizente com var_mes negativo; resultado interanual positivo do
     IBC-Br condizente com var_12m positivo.
  7. Nenhum vício de estilo identificado frente ao CLAUDE.MD (fontes SGS
     corretas, convenção IBC-Br respeitada, unidade do câmbio tratada como
     prescrito, falha por série via extrai()).
  8. Tom estritamente descritivo, sem linguagem de previsão; as únicas
     comparações temporais restantes (IPCA sem atualização em jul/2026,
     IBC-Br sem atualização em jun/2026) já haviam sido aprovadas
     anteriormente e permanecem inalteradas.
  9. _quarto.yml preserva a linha `from: markdown-tex_math_dollars` e não
     foi editado nesta correção; o YAML do boletim.qmd (linhas 1–12) não
     redeclara `from:`.
