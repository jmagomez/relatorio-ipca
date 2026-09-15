# relatorio-ipca — briefing do projeto

Este repositório hospeda **dois produtos** que compartilham a camada `R/`:

| Produto | Arquivo | Periodicidade | Quem gera |
|---|---|---|---|
| **Relatório IPCA** | `relatorio_ipca.qmd` | mensal, sob demanda | `quarto render` |
| **Boletim Macro Semanal** | `boletim.qmd` | segunda-feira | time de agentes (`/gerar-boletim`) |

O Relatório IPCA é analítico e aprofundado: nível, ritmo, núcleo, difusão,
sazonalidade e decomposição por grupo. O Boletim Macro é um quadro-resumo
semanal de quatro indicadores, enviado por e-mail.

---

## Fontes

| Série | Código | Uso |
|---|---|---|
| IPCA — variação mensal | SGS 433 | ambos |
| Meta de inflação | SGS 13521 | relatório mensal |
| Câmbio R$/US$ (venda) | SGS 1 | boletim semanal |
| Selic meta | SGS 432 | boletim semanal |
| IBC-Br original | SGS 24363 | boletim semanal |
| IBC-Br com ajuste sazonal | SGS 24364 | boletim semanal |
| IPCA por grupo (variação e peso) | SIDRA 7060, variáveis 63 e 66 | relatório mensal |

Núcleos oficiais do BCB: catálogo em `R/nucleos.R`, o conjunto do **Estudo
Especial 102/2021** — médias aparadas com suavização (**4466**), exclusão EX0
(**11427**), exclusão EX3 (**27839**), dupla ponderação (**16122**) e percentil
55 (**28750**).

**Cuidado com 28751**: é o núcleo Ex-alimentação e energia (EX-FE), não o
percentil 55. A primeira versão deste catálogo trazia esse código como P55, e o
relatório teria publicado um gráfico rotulado "Percentil 55" com dados do
EX-FE. O par (código, nome) está fixado em `test-nucleos-oficiais.R`; confira no
SGS (Localizar séries → Por código) antes de alterar qualquer linha.

Além disso, `validar_serie_nucleo()` confere em tempo de execução as
propriedades estruturais (mensal, ±5% ao mês, ≥24 meses de sobreposição,
volatilidade menor que a do cheio, correlação positiva) antes de publicar; série
reprovada é descartada com aviso. Essa verificação protege contra série
**grosseiramente** trocada — nível em vez de variação, frequência errada — e
**não** contra troca entre dois núcleos do mesmo índice: o EX-FE passaria nas
cinco checagens. As duas camadas são necessárias. Nunca remova nenhuma delas,
nem publique um núcleo sem o código SGS no rótulo.

---

## Regime de metas — meta contínua

Desde **janeiro de 2025** a meta de inflação é **contínua**: centro de 3,00%
com tolerância de ±1,5 p.p., avaliada **mês a mês** sobre o IPCA acumulado em
doze meses. O descumprimento se caracteriza quando o índice fica fora do
intervalo por **seis meses consecutivos**, e então o presidente do BC envia
carta aberta ao Ministro da Fazenda.

Não descreva a meta como de ano-calendário, e não repita a formulação antiga
de "dois trimestres consecutivos" — ambas estavam no texto do relatório e
foram corrigidas.

---

## Convenções de cálculo (inegociáveis)

### IPCA
- Acumulado no ano e em 12 meses: **produtório composto**
  `(prod(1 + x/100) - 1) * 100`, nunca soma simples de variações mensais.
- Trimestre anualizado: `(prod(1 + x/100)^4 - 1) * 100` sobre os três últimos
  meses. **Sem ajuste sazonal** — o rótulo do gráfico diz isso, e o texto
  precisa dizer também.

### IBC-Br
- `var_mes` → série **com ajuste sazonal** (24364), mês contra mês anterior.
- `var_ano` e `var_12m` → série **original** (24363), por **média de período**:
  média dos meses correspondentes contra a média dos mesmos meses do período
  anterior.

  Comparar nível contra nível em série sem ajuste sazonal é erro. Era o que a
  versão anterior fazia (nível de junho/2026 contra 31/dez/2025) e publicava
  +2,52% no ano quando o correto era +1,52%.

### Selic e câmbio
- Selic sempre em **pontos percentuais** (p.p.), nunca em pontos-base.
- Câmbio em **R$/US$**, com os dois cifrões, e valores com prefixo "R$ ".

### Geral
- Falha **por série**, nunca global. Uma fonte fora do ar não derruba o
  relatório: o indicador vira "indisponível nesta semana".
- Nenhum valor é estimado, interpolado ou arredondado além do que a fonte
  publica.
- Nenhuma data de referência fixa no código. `R/coleta_sgs.R` e
  `R/gerar_resumo.R` recebem a data por argumento de linha de comando.
- Nenhum caminho absoluto. `raiz_projeto()` localiza a raiz procurando
  `_quarto.yml`.

---

## Unidade do câmbio: R$/US$

O Pandoc lê o trecho entre dois `$` como fórmula matemática, e por isso
`R$/US$` era publicado como "R/US". O `_quarto.yml` desliga a extensão
(`from: markdown-tex_math_dollars`), então o cifrão é sempre literal e o
`boletim.qmd` pode escrever `R$/US$` direto.

Essa linha é a única proteção que sobrevive à regeneração semanal do
`boletim.qmd` pelo redator — **não remova, e não redeclare `from:`** no YAML do
`boletim.qmd`.

---

## Cache do Quarto

`execute: freeze: false` no `_quarto.yml`, deliberadamente.

Com `freeze: auto`, o Quarto só reexecuta um chunk quando o **código** muda.
Como a coleta consulta as APIs em tempo de execução, o código fica idêntico de
um mês para o outro e o chunk nunca reexecutava: o relatório publicava os dados
congelados da última edição do R. Não reative o freeze.

---

## Locale

Os workflows definem `LANG=C.UTF-8` e `LC_ALL=C.UTF-8`. Em locale C, o R lê os
fontes como latin1 e publica "inflação" como "infla....o", além de rotular os
eixos com meses em inglês. Os gráficos usam `rotulo_mes()` em vez de
`date_labels = "%b"` para não depender de locale nem no caso de o env sumir.

Em locale C, `source()` e o carregador do testthat interpretam o encoding dos
arquivos de forma **diferente**: o mesmo texto acentuado chega como bytes UTF-8
crus de um lado e como caractere de outro. Por isso o teste que fixa os nomes
das séries compara apenas o esqueleto ASCII — e por isso não se deve usar
escapes `\uXXXX` em teste que compare com literal vindo de `R/`.

---

## Estrutura

```
R/
  coleta.R        coleta do relatório mensal (rbcb + sidrar)
  coleta_sgs.R    coleta do boletim semanal (catálogo de séries SGS)
  tratamento.R    funções puras: acumulados, anualizado, difusão,
                  média aparada, variação por média de período, meta contínua
  nucleos.R       núcleo e difusão do SIDRA; núcleos oficiais do SGS com
                  verificação de identidade em tempo de execução
  gerar_resumo.R  monta output/dados/resumo.csv (4 indicadores)
  graficos.R      ggplot2 + camada interativa opcional (ggiraph)
tests/testthat/   testes das funções puras — rodam no CI antes do render
relatorio_ipca.qmd  relatório mensal
boletim.qmd         boletim semanal (regenerado pelo redator)
.claude/agents/     time de agentes do boletim semanal
```

---

## Ao mexer no código

- Todo defeito corrigido ganha um teste em `tests/testthat/` que nomeia o
  defeito. Rode com `cd tests && Rscript testthat.R`.
- `ggiraph` é opcional: `renderizar()` devolve o ggplot estático quando o
  pacote não está instalado. Não torne o render dependente dele.
- `boletim.html` é versionado de propósito. O agente publicador o commita, e é
  esse commit que sinaliza "há boletim novo" para o workflow disparar o e-mail.
  Desversioná-lo faria o envio parar em silêncio.
