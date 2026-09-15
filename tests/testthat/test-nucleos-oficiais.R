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
