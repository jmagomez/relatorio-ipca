# Verificação de identidade dos núcleos oficiais do SGS.
#
# Não há endpoint público que devolva o nome de uma série do SGS, então a
# identidade é verificada pelo comportamento. Estes testes exercitam tanto uma
# série que DEVE passar quanto os quatro modos de série trocada que o código
# precisa recusar — é o que separa "ligamos os núcleos" de "publicamos cinco
# códigos e torcemos para estarem certos".

source(file.path(rprojroot_raiz(), "R", "tratamento.R"))
source(file.path(rprojroot_raiz(), "R", "nucleos.R"))
source(file.path(rprojroot_raiz(), "R", "graficos.R"))

.ipca_de_teste <- function(n = 60) {
  set.seed(42)
  data.frame(
    data = seq(as.Date("2021-01-01"), by = "month", length.out = n),
    ipca_mm = rnorm(n, mean = 0.45, sd = 0.45)
  )
}

test_that("núcleo legítimo passa na verificação", {
  ipca <- .ipca_de_teste()
  # Núcleo: mesma tendência, menos volátil — é a definição.
  nucleo <- data.frame(data = ipca$data, valor = 0.45 + 0.4 * (ipca$ipca_mm - 0.45))
  exame <- validar_serie_nucleo(nucleo, ipca)
  expect_true(exame$ok)
  expect_length(exame$motivos, 0)
})

test_that("índice de nível é recusado pela ordem de grandeza", {
  ipca <- .ipca_de_teste()
  nivel <- data.frame(data = ipca$data, valor = seq(100, 130, length.out = nrow(ipca)))
  exame <- validar_serie_nucleo(nivel, ipca)
  expect_false(exame$ok)
  expect_true(any(grepl("faixa de varia", exame$motivos)))
})

test_that("série diária é recusada pela frequência", {
  ipca <- .ipca_de_teste()
  diaria <- data.frame(
    data = seq(as.Date("2021-01-01"), by = "day", length.out = 400),
    valor = rnorm(400, 0.02, 0.01)
  )
  exame <- validar_serie_nucleo(diaria, ipca)
  expect_false(exame$ok)
  expect_true(any(grepl("mensal", exame$motivos)))
})

test_that("série mais volátil que o índice cheio não é núcleo", {
  ipca <- .ipca_de_teste()
  # Mesma direção, porém amplificada: por definição não apara cauda nenhuma.
  ruidosa <- data.frame(data = ipca$data, valor = 0.45 + 2 * (ipca$ipca_mm - 0.45))
  exame <- validar_serie_nucleo(ruidosa, ipca)
  expect_false(exame$ok)
  expect_true(any(grepl("volatilidade", exame$motivos)))
})

test_that("indicador não correlacionado é recusado", {
  ipca <- .ipca_de_teste()
  set.seed(7)
  alheio <- data.frame(data = ipca$data, valor = rnorm(nrow(ipca), 0.45, 0.2))
  exame <- validar_serie_nucleo(alheio, ipca)
  expect_false(exame$ok)
  expect_true(any(grepl("correla", exame$motivos)))
})

test_that("série curta é recusada antes de qualquer estatística", {
  ipca <- .ipca_de_teste()
  curta <- data.frame(data = head(ipca$data, 6), valor = rep(0.4, 6))
  exame <- validar_serie_nucleo(curta, ipca)
  expect_false(exame$ok)
  expect_true(any(grepl("curta", exame$motivos)))
})

test_that("o rótulo publicado sempre expõe o código SGS", {
  # Auditabilidade: se um código estiver errado, o leitor consegue ver qual é.
  expect_equal(rotulo_nucleo("Exclusão EX3", 27839L), "Exclusão EX3 (SGS 27839)")
  for (i in seq_len(nrow(NUCLEOS_SGS))) {
    rotulo <- rotulo_nucleo(NUCLEOS_SGS$descricao[i], NUCLEOS_SGS$codigo[i])
    expect_true(grepl(as.character(NUCLEOS_SGS$codigo[i]), rotulo, fixed = TRUE))
  }
})

test_that("catálogo declara os campos que a coleta usa", {
  expect_true(all(c("chave", "codigo", "descricao") %in% names(NUCLEOS_SGS)))
  expect_true(all(NUCLEOS_SGS$codigo > 0))
  expect_equal(anyDuplicated(NUCLEOS_SGS$codigo), 0L)
})

test_that("a coleta verifica identidade por padrão", {
  # Guarda contra publicar série com rótulo não verificado: `verificar` tem de
  # começar ligado, senão um código errado chegaria ao relatório sem exame.
  expect_true(formals(coletar_nucleos_oficiais)$verificar)
})

test_that("coleta devolve vazio sem rbcb, sem derrubar o relatório", {
  skip_if(requireNamespace("rbcb", quietly = TRUE), "rbcb instalado")
  resultado <- suppressWarnings(coletar_nucleos_oficiais(.ipca_de_teste()))
  expect_equal(nrow(resultado), 0L)
  expect_true(all(c("data", "chave", "codigo", "rotulo", "valor") %in% names(resultado)))
})

test_that("gráfico dos núcleos oficiais devolve NULL sem séries aprovadas", {
  vazio <- data.frame(
    data = as.Date(character()), chave = character(), codigo = integer(),
    rotulo = character(), valor = numeric()
  )
  expect_null(grafico_nucleos_oficiais(vazio, .ipca_de_teste()))
})


# ── O catálogo de códigos SGS ────────────────────────────────────────────────
#
# Este bloco existe por causa de um defeito real: a primeira versão do
# catálogo trazia 28751 como "Percentil 55", e 28751 é o núcleo
# Ex-alimentação e energia (EX-FE). O percentil 55 é 28750.
#
# O ponto importante é que `validar_serie_nucleo()` NÃO pegaria isso — o EX-FE
# é um núcleo legítimo do IPCA e passa nas cinco checagens estruturais. A
# verificação comportamental protege contra série grosseiramente trocada, não
# contra troca entre dois núcleos do mesmo índice. Fixar o par (código, nome)
# é a única proteção contra essa classe de erro.
#
# Conferido em https://www3.bcb.gov.br/sgspub/ → Localizar séries → Por código.

test_that("o catalogo traz exatamente os cinco nucleos do EE 102/2021", {
  expect_setequal(NUCLEOS_SGS$chave, c("ms", "ex0", "ex3", "dp", "p55"))
  expect_equal(nrow(NUCLEOS_SGS), 5L)
})

test_that("cada chave aponta para o codigo SGS conferido no proprio SGS", {
  esperado <- c(ms = 4466L, ex0 = 11427L, ex3 = 27839L, dp = 16122L, p55 = 28750L)
  obtido <- stats::setNames(NUCLEOS_SGS$codigo, NUCLEOS_SGS$chave)
  expect_equal(obtido[names(esperado)], esperado)
})

test_that("28751 nao volta ao catalogo: e o EX-FE, nao o percentil 55", {
  expect_false(28751L %in% NUCLEOS_SGS$codigo)
})

test_that("o nome completo de cada nucleo e o que o SGS publica", {
  # Comparacao pelo esqueleto ASCII, de proposito.
  #
  # Em locale C, `source()` de R/ e o carregador do testthat interpretam o
  # encoding dos arquivos de forma diferente: o mesmo "Nucleo" chega como bytes
  # UTF-8 crus de um lado e como caractere de outro, e a igualdade falha por
  # motivo que nada tem a ver com o catalogo. Removendo tudo fora de ASCII, os
  # dois lados ficam comparaveis — e o que discrimina um nucleo do outro
  # ("EX0", "EX3", "Percentil 55", "dupla ponderacao") e justamente ASCII.
  so_ascii <- function(x) gsub("[^ -~]", "", x)

  esperado <- c(
    ms  = "ndice Nacional de Preos ao Consumidor Amplo (IPCA) - Ncleo mdias aparadas com suavizao",
    ex0 = "ndice Nacional de Preos ao Consumidor Amplo (IPCA) - Ncleo por excluso - EX0",
    ex3 = "ndice Nacional de Preos ao Consumidor Amplo (IPCA) - Ncleo por excluso - EX3",
    dp  = "ndice Nacional de Preos ao Consumidor Amplo (IPCA) - Ncleo de dupla ponderao",
    p55 = "ndice Nacional de Preos ao Consumidor Amplo (IPCA) - Ncleo Percentil 55"
  )
  obtido <- stats::setNames(so_ascii(NUCLEOS_SGS$nome_sgs), NUCLEOS_SGS$chave)
  expect_equal(obtido[names(esperado)], esperado)
})

test_that("os nucleos por exclusao sao o EX0 e o EX3, nao o EX1, EX2 ou EX-FE", {
  # O EE 102/2021 tirou EX1 e EX2 do conjunto; o EX-FE (SGS 28751) nunca
  # entrou. Este teste falha se alguem trocar um pelo outro.
  exclusao <- NUCLEOS_SGS$nome_sgs[NUCLEOS_SGS$chave %in% c("ex0", "ex3")]
  expect_true(any(grepl("EX0", exclusao, fixed = TRUE)))
  expect_true(any(grepl("EX3", exclusao, fixed = TRUE)))
  expect_false(any(grepl("EX1", NUCLEOS_SGS$nome_sgs, fixed = TRUE)))
  expect_false(any(grepl("EX2", NUCLEOS_SGS$nome_sgs, fixed = TRUE)))
  expect_false(any(grepl("EX-FE", NUCLEOS_SGS$nome_sgs, fixed = TRUE)))
})

test_that("a descricao curta e coerente com o nome do SGS", {
  # Comparacao em minusculas e sem os separadores, para nao depender de
  # maiuscula inicial nem do " - " que o SGS usa antes da sigla.
  normalizar <- function(x) gsub("[^[:alnum:]]+", "", tolower(x))
  for (i in seq_len(nrow(NUCLEOS_SGS))) {
    expect_true(
      grepl(normalizar(NUCLEOS_SGS$descricao[i]), normalizar(NUCLEOS_SGS$nome_sgs[i]), fixed = TRUE),
      info = paste0("descricao incoerente na linha ", i, ": ", NUCLEOS_SGS$chave[i])
    )
    expect_true(grepl("(IPCA)", NUCLEOS_SGS$nome_sgs[i], fixed = TRUE))
  }
})

test_that("o rotulo publicado carrega o codigo SGS, para auditoria", {
  rotulos <- rotulo_nucleo(NUCLEOS_SGS$descricao, NUCLEOS_SGS$codigo)
  expect_true(all(grepl("\\(SGS \\d+\\)$", rotulos)))
  expect_true(any(grepl("(SGS 28750)", rotulos, fixed = TRUE)))
})
