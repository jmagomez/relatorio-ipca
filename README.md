# relatorio-ipca

Dois produtos de conjuntura macroeconômica brasileira, construídos sobre a
mesma camada de coleta e tratamento em R.

| Produto | Arquivo | Periodicidade | Entrega |
|---|---|---|---|
| **Relatório IPCA** | `relatorio_ipca.qmd` | mensal | HTML autocontido, publicado no Posit Connect Cloud |
| **Boletim Macro Semanal** | `boletim.qmd` | segunda-feira, 07h BRT | e-mail com o HTML anexo |

Até a v2 o README documentava apenas o primeiro e o `CLAUDE.MD` apenas o
segundo — quem chegava ao repositório via um deles não sabia da existência do
outro.

---

## Relatório IPCA

Análise mensal da inflação ao consumidor em cinco leituras complementares:

| Seção | Pergunta que responde |
|---|---|
| **Panorama mensal** | qual foi a inflação do mês e como se compara com os últimos 24 |
| **Ritmo** | o que está sendo gerado *agora* — trimestre anualizado contra o acumulado em 12 meses, que carrega inércia |
| **Núcleo e difusão** | a alta veio de poucos grupos ou de muitos; é choque ou tendência |
| **Meta contínua** | onde o acumulado está frente à meta, e há quantos meses consecutivos fora da banda |
| **Padrão sazonal** | o movimento do mês é recorrente no calendário ou atípico |
| **Contribuições** | qual grupo de despesa produziu o resultado |

Ritmo, núcleo e difusão são novos na v2. Sem eles não se distingue choque
pontual de pressão disseminada, que é a leitura relevante para política
monetária.

### Regime de metas

Desde **janeiro de 2025** vale a **meta contínua**: centro de 3,00% com
tolerância de ±1,5 p.p., avaliada mês a mês sobre o IPCA acumulado em doze
meses. O descumprimento se caracteriza com **seis meses consecutivos** fora do
intervalo. O relatório conta esses meses e sinaliza quando o prazo se aproxima.

### Como renderizar

```bash
quarto render relatorio_ipca.qmd
```

Gera `relatorio_ipca.html` autocontido na raiz. **O cache está desligado**
(`freeze: false`): cada renderização consulta as APIs e reflete os dados mais
recentes. Com `freeze: auto` — a configuração anterior — o Quarto só
reexecutava um chunk quando o *código* mudava, e como a coleta é feita em tempo
de execução o relatório publicava indefinidamente os dados da última vez em que
alguém editou o R.

---

## Boletim Macro Semanal

Quadro de quatro indicadores (IPCA, câmbio, Selic e IBC-Br) gerado por um time
de agentes e enviado por e-mail toda segunda-feira.

```
pesquisador-dados → analista → redator → revisor → publicador
     coleta SGS      resumo.csv   boletim.qmd   parecer    render + commit
```

O publicador só roda com `logs/revisao.md` começando por `ok`. O commit do
`boletim.html` é o sinal que dispara o envio do e-mail — por isso esse arquivo
é versionado de propósito.

```bash
Rscript R/coleta_sgs.R 2026-09-14    # coleta as séries
Rscript R/gerar_resumo.R 2026-09-14  # monta output/dados/resumo.csv
quarto render boletim.qmd
```

---

## Fontes

| Série | Código | Via |
|---|---|---|
| IPCA — variação mensal | SGS 433 | `rbcb` |
| Meta de inflação | SGS 13521 | `rbcb` |
| Câmbio R$/US$ (venda, fechamento) | SGS 1 | `rbcb` |
| Selic meta | SGS 432 | `rbcb` |
| IBC-Br — original | SGS 24363 | `rbcb` |
| IBC-Br — com ajuste sazonal | SGS 24364 | `rbcb` |
| IPCA por grupo: variação e peso | SIDRA 7060, var. 63 e 66 | `sidrar` |

### Núcleos oficiais do BCB

O relatório publica os cinco núcleos do conjunto que o BCB usa em análise de
conjuntura, definido no [Estudo Especial 102/2021](https://www.bcb.gov.br/conteudo/relatorioinflacao/EstudosEspeciais/EE102_Atualizacao_conjunto_nucleos_inflacao_comumente_considerados_pelo_BCB_para_analise_de_conjuntura_economica.pdf)
— que aposentou EX1, EX2 e as médias aparadas *sem* suavização, e acrescentou o
percentil 55:

| Núcleo | SGS | Nome no SGS |
|---|---|---|
| Médias aparadas com suavização | **4466** | *…Núcleo médias aparadas com suavização* |
| Exclusão EX0 | **11427** | *…Núcleo por exclusão - EX0* |
| Exclusão EX3 | **27839** | *…Núcleo por exclusão - EX3* |
| Dupla ponderação | **16122** | *…Núcleo de dupla ponderação* |
| Percentil 55 | **28750** | *…Núcleo Percentil 55* |

> ⚠️ **28751 não é o percentil 55** — é o núcleo Ex-alimentação e energia
> (EX-FE), que não faz parte deste conjunto. A primeira versão do catálogo
> trazia 28751 como P55; o relatório teria publicado um gráfico rotulado
> "Percentil 55" com os dados do EX-FE. Os pares (código, nome) foram conferidos
> um a um no [SGS](https://www3.bcb.gov.br/sgspub/) e estão fixados em
> `tests/testthat/test-nucleos-oficiais.R`.

Esse defeito **passaria despercebido pela verificação comportamental** descrita
abaixo: o EX-FE é um núcleo legítimo do IPCA e exibe todas as propriedades
exigidas. As duas camadas cobrem coisas diferentes e ambas são necessárias.

Não existe endpoint público que devolva o *nome* de uma série do SGS em JSON,
então a identidade também é verificada pelo comportamento. Antes de publicar,
cada série precisa exibir as propriedades estruturais de um núcleo do IPCA:

| Verificação | Por quê |
|---|---|
| Frequência mensal | série diária ou anual é outra coisa |
| Variação dentro de ±5% ao mês | fora disso é nível de índice, acumulado ou outra unidade |
| Ao menos 24 meses de sobreposição com o IPCA | menos que isso não permite comparar |
| Volatilidade **menor** que a do índice cheio | é a propriedade que *define* um núcleo |
| Correlação positiva com o índice cheio | mede o mesmo fenômeno |

Série reprovada é descartada com aviso no log do render, e o relatório segue com
as medidas derivadas do SIDRA. O rótulo publicado sempre carrega o código SGS,
para auditoria direta em [www3.bcb.gov.br/sgspub](https://www3.bcb.gov.br/sgspub/)
— foi exatamente essa auditoria que revelou a troca do 28751.

O que a verificação comportamental **não** faz: distinguir dois núcleos do mesmo
índice. Ela pega série grosseiramente trocada (nível em vez de variação,
frequência errada, unidade errada); não pega EX-FE no lugar de P55. Para isso
existe o teste que fixa o par (código, nome).

Diagnóstico manual do catálogo:

```r
source("R/nucleos.R")
validar_catalogo_nucleos(df_ipca)   # veredito por série, sem publicar nada
```

Em paralelo, o relatório mantém núcleo por médias aparadas e difusão calculados
diretamente dos microdados do SIDRA — mais grossos que os oficiais (nove grupos
em vez de 377 subitens), porém inteiramente reproduzíveis. A comparação entre as
duas camadas é informativa: convergência reforça a leitura; divergência indica
que a granularidade importa naquele mês.

---

## Convenções de cálculo

- **IPCA acumulado**: produtório composto `(prod(1 + x/100) - 1) * 100`, nunca
  soma de variações mensais.
- **Trimestre anualizado**: `(prod(1 + x/100)^4 - 1) * 100`, **sem ajuste
  sazonal** — leia contra o padrão sazonal da própria série.
- **IBC-Br**: `var_mes` da série com ajuste sazonal (24364), mês contra mês;
  `var_ano` e `var_12m` da série original (24363), por **média de período**.

  > Na v1, `var_ano` comparava o nível do índice bruto contra 31/dez do ano
  > anterior. Índice de volume sem ajuste sazonal carrega a sazonalidade dos
  > dois meses comparados. O boletim publicava **+2,52%** no ano quando o
  > correto era **+1,52%**.

- **Selic** sempre em pontos percentuais, nunca em pontos-base.
- **Falha por série, nunca global**: uma fonte indisponível vira "indisponível
  nesta semana"; as demais seguem.

---

## Pré-requisitos

```r
install.packages(c(
  "rbcb", "sidrar", "slider",
  "dplyr", "tidyr", "lubridate",
  "ggplot2", "scales", "knitr",
  "ggiraph",   # opcional: adiciona tooltip e zoom aos gráficos
  "testthat"   # apenas para rodar os testes
))
```

[Quarto 1.3+](https://quarto.org/docs/get-started/)

`ggiraph` é opcional por construção: sem ele os gráficos saem estáticos e o
render funciona igual.

---

## Testes

```bash
cd tests && Rscript testthat.R
```

98 testes das funções puras de `R/tratamento.R`, `R/nucleos.R` e
`R/coleta_sgs.R`: acumulados, trimestre anualizado, média móvel, difusão, média
aparada ponderada, variação por média de período, contagem de meses fora da
banda da meta, a verificação de identidade dos núcleos oficiais — exercitando
tanto um núcleo legítimo quanto os quatro modos de série trocada (índice de
nível, série diária, série mais volátil que o cheio e indicador não
correlacionado) — e o bloco que **fixa o par (código, nome)** de cada núcleo do
SGS. Cada teste corresponde a uma definição verificável ou a um defeito
corrigido, incluindo os dois que documentam o erro do IBC-Br e o que impede o
28751 de voltar ao catálogo.

O CI roda os testes **antes** do render: uma regressão de cálculo falha em
segundos, enquanto o render completo consulta as APIs e leva minutos.

---

## Locale

Os workflows definem `LANG=C.UTF-8` e `LC_ALL=C.UTF-8`. Em locale C o R lê os
fontes como latin1 e publica "inflação" como "infla....o"; os eixos também
saem com meses em inglês. Os gráficos usam `rotulo_mes()` em vez de
`date_labels = "%b"` para não depender do locale nem quando a variável falta.

Em locale C, `source()` e o carregador do testthat interpretam o encoding dos
arquivos de forma **diferente**: o mesmo texto acentuado chega como bytes UTF-8
crus de um lado e como caractere de outro. Por isso o teste que fixa os nomes
das séries compara apenas o esqueleto ASCII, e escapes `\uXXXX` não devem ser
usados em teste que compare com literal vindo de `R/`.

## Licença

MIT — ver [LICENSE](LICENSE).
