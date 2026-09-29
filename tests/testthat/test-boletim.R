# Testes do Boletim Macro Semanal: gráficos e corpo do e-mail.
#
# Cada bloco nomeia o defeito que o originou.

source(file.path(rprojroot_raiz(), "R", "tratamento.R"))
source(file.path(rprojroot_raiz(), "R", "graficos.R"))
source(file.path(rprojroot_raiz(), "R", "graficos_boletim.R"))

# Série sintética com uma corrida fora da banda que COMEÇA antes de jan/2025
# e atravessa a virada do regime — a forma exata do caso real.
serie_meta_sintetica <- function() {
  datas <- seq(as.Date("2024-08-01"), by = "month", length.out = 26)
  # acum_12m: dentro até set/24, fora de out/24 a out/25, dentro depois.
  acum <- c(
    4.0, 4.2, # ago, set/24 — dentro
    rep(5.2, 13), # out/24 .. out/25 — fora (13 meses corridos)
    rep(4.0, 11) # nov/25 em diante — dentro
  )
  data.frame(data = datas, acum_12m = acum)
}


# ── O anacronismo: aplicar a regra de 2025 ao passado ──────────────────────
#
# A meta contínua vigora desde jan/2025. Antes disso a meta era de
# ano-calendário e o centro era OUTRO: 3,25% em 2023, 3,50% em 2022. Contar
# como descumprimento um mês de 2024 é julgar o passado pela régua do presente.

test_that("a contagem de meses fora reinicia na entrada do regime contínuo", {
  df <- avaliar_meta_continua(serie_meta_sintetica(), META_CENTRO, META_BANDA)
  s <- situacao_meta(df)

  # A corrida na série inteira tem 13 meses (out/24 a out/25), mas só 10 deles
  # caem sob o regime contínuo (jan/25 a out/25).
  expect_equal(max(df$meses_consecutivos_fora), 13L)
  expect_equal(s$maior_sequencia_fora, 10L)
})

test_that("o gráfico não marca como fora da banda nenhum mês anterior a jan/2025", {
  df <- avaliar_meta_continua(serie_meta_sintetica(), META_CENTRO, META_BANDA)
  p <- grafico_meta_continua(df, anos = 6)

  # A camada de pontos é a única que recebe `data` próprio; se ela existir,
  # nenhuma de suas linhas pode ser anterior ao início do regime.
  camadas_com_dados <- Filter(
    function(l) is.data.frame(l$data) && nrow(l$data) > 0 && "data" %in% names(l$data),
    p$layers
  )
  expect_gt(length(camadas_com_dados), 0)
  for (camada in camadas_com_dados) {
    expect_true(
      all(camada$data$data >= INICIO_META_CONTINUA),
      info = "ponto de 'fora da banda' desenhado antes da vigência do regime"
    )
  }
})

test_that("a contagem sob o regime não conta meses que o regime não governava", {
  df <- avaliar_meta_continua(serie_meta_sintetica(), META_CENTRO, META_BANDA)
  s <- situacao_meta(df)
  expect_equal(s$total_meses_sob_regime, sum(df$data >= INICIO_META_CONTINUA))
  expect_lte(s$meses_fora_sob_regime, s$total_meses_sob_regime)
})


# ── A leitura que faltava ─────────────────────────────────────────
#
# O boletim publicava o acumulado em doze meses como número solto, sem dizer
# onde ele cai dentro da banda que define o regime.

test_that("situacao_meta informa a folga até o teto e o estado corrente", {
  df <- avaliar_meta_continua(
    data.frame(data = seq(as.Date("2025-01-01"), by = "month", length.out = 6),
               acum_12m = c(4.0, 4.1, 4.2, 4.3, 4.4, 4.22)),
    META_CENTRO, META_BANDA
  )
  s <- situacao_meta(df)

  expect_false(s$fora)
  expect_equal(s$teto, 4.5)
  expect_equal(s$piso, 1.5)
  expect_equal(s$folga_ate_o_teto, 4.5 - 4.22, tolerance = 1e-9)
  expect_equal(s$limite_descumprimento, 6L)
})

test_that("frase_meta nunca publica uma contagem zerada", {
  # O boletim de 2026-09-28 saiu com "Há 0 mês(es) consecutivo(s) fora da
  # banda" — o agente redator montava a frase à mão a partir de
  # sit$meses_consecutivos_fora, que vale 0 justamente quando o índice está
  # DENTRO. A redação pior aparecia quando a notícia era boa.
  dentro <- avaliar_meta_continua(
    data.frame(data = seq(as.Date("2025-01-01"), by = "month", length.out = 20),
               acum_12m = c(rep(5.2, 18), 4.0, 4.2)),
    META_CENTRO, META_BANDA
  )
  f <- frase_meta(situacao_meta(dentro))

  # \\b evita casar o "0 m" de "20 meses", que é legítimo.
  expect_false(grepl("\\b0 m", f))
  expect_false(grepl("\\b0º", f))
  expect_false(grepl("mês\\(es\\)|consecutivo\\(s\\)", f))
  expect_true(grepl("dentro", f))
})

test_that("frase_meta usa a ênfase pedida e serve aos dois destinos", {
  df <- avaliar_meta_continua(
    data.frame(data = seq(as.Date("2025-01-01"), by = "month", length.out = 6),
               acum_12m = c(4.0, 4.1, 4.2, 4.3, 4.4, 4.22)),
    META_CENTRO, META_BANDA
  )
  s <- situacao_meta(df)

  md <- frase_meta(s)
  html <- frase_meta(s, c("<strong>", "</strong>"))

  # O .qmd recebe Markdown; o corpo do e-mail recebe HTML. Mesma frase.
  expect_true(grepl("**", md, fixed = TRUE))
  expect_false(grepl("<strong>", md, fixed = TRUE))
  expect_true(grepl("<strong>", html, fixed = TRUE))

  expect_null(frase_meta(NULL))
})

test_that("série fora da banda reporta a corrida corrente", {
  df <- avaliar_meta_continua(
    data.frame(data = seq(as.Date("2025-01-01"), by = "month", length.out = 4),
               acum_12m = c(4.0, 5.0, 5.1, 5.2)),
    META_CENTRO, META_BANDA
  )
  s <- situacao_meta(df)
  expect_true(s$fora)
  expect_equal(s$meses_consecutivos_fora, 3L)
})


# ── Selic em degraus, não em reta ───────────────────────────────────
#
# A meta Selic só muda por decisão do Copom e fica constante entre reuniões.
# Ligar as observações por reta inclinada desenha um ajuste gradual que não
# existe e sugere taxas intermediárias que nunca vigoraram.

test_that("o gráfico da Selic usa geom_step", {
  df <- data.frame(
    data = seq(as.Date("2025-01-01"), by = "day", length.out = 400),
    valor = rep(c(12.25, 13.25, 14.25, 15.00), each = 100)
  )
  p <- grafico_selic(df)
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomStep" %in% geoms)
  expect_false("GeomLine" %in% geoms)
})


# ── Falha por série, nunca global ───────────────────────────────────
#
# Regra do projeto: uma fonte fora do ar vira "indicador indisponível nesta
# semana" e não derruba o boletim.

test_that("série ausente ou curta devolve NULL em vez de erro", {
  vazio <- data.frame(data = as.Date(character()), valor = numeric())
  um_ponto <- data.frame(data = as.Date("2026-01-01"), valor = 1)

  for (f in list(grafico_selic, grafico_cambio, grafico_ibcbr)) {
    expect_null(f(NULL))
    expect_null(f(vazio))
    expect_null(f(um_ponto))
  }
  expect_null(grafico_meta_continua(NULL))
  expect_null(situacao_meta(NULL))
})

test_that("ler_serie_boletim devolve NULL para arquivo inexistente ou malformado", {
  expect_null(ler_serie_boletim(file.path(tempdir(), "nao-existe-jamais.csv")))

  ruim <- file.path(tempdir(), "sem-colunas.csv")
  utils::write.csv(data.frame(a = 1, b = 2), ruim, row.names = FALSE)
  expect_null(ler_serie_boletim(ruim))
})


# ── O corpo do e-mail ───────────────────────────────────────────
#
# O workflow enviava como corpo o boletim.html inteiro: 1.859 KB para 5,9 KB
# de conteúdo. O Gmail trunca acima de ~102 KB.

test_that("o corpo do e-mail cabe abaixo do limite de truncamento do Gmail", {
  source(file.path(rprojroot_raiz(), "R", "corpo_email.R"))
  html <- montar_corpo(
    "2026-09-28",
    dir_dados = file.path(rprojroot_raiz(), "output", "dados")
  )
  bytes <- nchar(html, type = "bytes")

  expect_lt(bytes, LIMITE_GMAIL_BYTES)
  # Margem larga: o corpo é uma tabela, não deve crescer uma ordem de grandeza.
  expect_lt(bytes, 40 * 1024)
})

test_that("o corpo do e-mail não usa recurso que cliente de e-mail descarta", {
  source(file.path(rprojroot_raiz(), "R", "corpo_email.R"))
  html <- montar_corpo(
    "2026-09-28",
    dir_dados = file.path(rprojroot_raiz(), "output", "dados")
  )

  # Gmail e Outlook removem SVG inline e JavaScript, e ignoram folha de estilo
  # externa. Um gráfico posto aqui simplesmente não apareceria.
  expect_false(grepl("<svg", html, fixed = TRUE))
  expect_false(grepl("<script", html, fixed = TRUE))
  expect_false(grepl("stylesheet", html, fixed = TRUE))
  expect_false(grepl(";base64,", html, fixed = TRUE))
})

test_that("nenhum NA vaza para o corpo do e-mail quando falta indicador", {
  vazio <- file.path(tempdir(), "dados-vazios")
  dir.create(vazio, showWarnings = FALSE)
  utils::write.csv(
    data.frame(
      indicador = "IPCA", unidade = "%", valor_atual = NA, data_ref = NA,
      var_mes = NA, var_ano = NA, var_12m = NA
    ),
    file.path(vazio, "resumo.csv"),
    row.names = FALSE
  )

  source(file.path(rprojroot_raiz(), "R", "corpo_email.R"))
  html <- montar_corpo("2026-09-28", dir_dados = vazio)

  expect_false(grepl(">NA<", html, fixed = TRUE))
  expect_true(grepl("indispon", html))
})

test_that("o corpo do e-mail preserva a unidade R$/US$", {
  source(file.path(rprojroot_raiz(), "R", "corpo_email.R"))
  html <- montar_corpo(
    "2026-09-28",
    dir_dados = file.path(rprojroot_raiz(), "output", "dados")
  )
  # O HTML é escrito direto, sem passar pelo Pandoc — o cifrão não corre o
  # risco de virar delimitador de fórmula matemática.
  expect_true(grepl("R$/US$", html, fixed = TRUE))
})
