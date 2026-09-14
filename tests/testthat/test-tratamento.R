# Testes das funções puras de tratamento.
# Cada teste com valor esperado calculado à mão a partir da definição.

source(file.path(rprojroot_raiz(), "R", "tratamento.R"))

test_that("acumulado em 12 meses usa capitalização composta", {
  df <- data.frame(data = seq(as.Date("2025-01-01"), by = "month", length.out = 12),
                   ipca_mm = rep(1, 12))
  resultado <- calcular_acumulado_12m(df)
  # (1,01)^12 - 1 = 12,6825%
  expect_equal(tail(resultado$acum_12m, 1), (1.01^12 - 1) * 100, tolerance = 1e-9)
  # Os 11 primeiros meses não têm janela completa.
  expect_true(all(is.na(head(resultado$acum_12m, 11))))
})

test_that("acumulado no ano reinicia em janeiro", {
  df <- data.frame(
    data = seq(as.Date("2025-11-01"), by = "month", length.out = 4),
    ipca_mm = c(1, 1, 2, 2)
  )
  resultado <- calcular_acumulado_ano(df)
  expect_equal(resultado$acum_ano[2], (1.01^2 - 1) * 100, tolerance = 1e-9)  # nov+dez/2025
  expect_equal(resultado$acum_ano[3], 2, tolerance = 1e-9)                    # jan/2026 sozinho
  expect_equal(resultado$acum_ano[4], (1.02^2 - 1) * 100, tolerance = 1e-9)  # jan+fev/2026
})

test_that("anualizado de 3 meses eleva a janela a 4 períodos", {
  df <- data.frame(data = seq(as.Date("2026-01-01"), by = "month", length.out = 3),
                   ipca_mm = rep(0.5, 3))
  resultado <- calcular_anualizado(df, n = 3)
  expect_equal(tail(resultado$anualizado_3m, 1), (1.005^12 - 1) * 100, tolerance = 1e-9)
  expect_true(all(is.na(head(resultado$anualizado_3m, 2))))
})

test_that("anualizado é maior que o acumulado 12m quando o ritmo acelera", {
  # Seis meses a 0,2% seguidos de três meses a 0,8%: o ritmo corrente supera a média.
  df <- data.frame(
    data = seq(as.Date("2025-04-01"), by = "month", length.out = 12),
    ipca_mm = c(rep(0.2, 9), rep(0.8, 3))
  )
  df <- calcular_anualizado(calcular_acumulado_12m(df), n = 3)
  expect_gt(tail(df$anualizado_3m, 1), tail(df$acum_12m, 1))
})

test_that("média móvel suaviza a série", {
  df <- data.frame(data = seq(as.Date("2026-01-01"), by = "month", length.out = 4),
                   ipca_mm = c(0, 3, 0, 3))
  resultado <- calcular_media_movel(df, n = 3)
  expect_equal(resultado$media_movel_3m[3], 1, tolerance = 1e-9)
  expect_equal(resultado$media_movel_3m[4], 2, tolerance = 1e-9)
})

test_that("difusão conta itens com variação positiva", {
  df <- data.frame(
    data = rep(as.Date("2026-08-01"), 4),
    item = letters[1:4],
    variacao = c(0.5, -0.2, 0, 1.1)
  )
  resultado <- calcular_difusao(df)
  expect_equal(resultado$n_itens, 4L)
  expect_equal(resultado$n_positivos, 2L)
  expect_equal(resultado$difusao, 50)
})

test_that("difusão trata variação zero como não positiva", {
  df <- data.frame(data = rep(as.Date("2026-08-01"), 2), item = c("a", "b"),
                   variacao = c(0, 0))
  expect_equal(calcular_difusao(df)$difusao, 0)
})

test_that("difusão ignora itens sem variação informada", {
  df <- data.frame(data = rep(as.Date("2026-08-01"), 3), item = letters[1:3],
                   variacao = c(1, NA, -1))
  resultado <- calcular_difusao(df)
  expect_equal(resultado$n_itens, 2L)
  expect_equal(resultado$difusao, 50)
})

test_that("média aparada descarta as caudas pelo peso", {
  # Quatro itens de peso igual (25% cada) e corte de 25% em cada cauda:
  # sobra exatamente o miolo, itens com variação 1 e 2 → núcleo 1,5.
  df <- data.frame(
    data = rep(as.Date("2026-08-01"), 4),
    item = letters[1:4],
    variacao = c(-10, 1, 2, 10),
    peso = rep(25, 4)
  )
  resultado <- calcular_media_aparada(df, corte = 25)
  expect_equal(resultado$nucleo_aparado, 1.5, tolerance = 1e-9)
  expect_equal(resultado$peso_utilizado, 50, tolerance = 1e-9)
})

test_that("média aparada sem corte reproduz a média ponderada", {
  df <- data.frame(
    data = rep(as.Date("2026-08-01"), 3),
    item = letters[1:3],
    variacao = c(1, 2, 3),
    peso = c(50, 30, 20)
  )
  resultado <- calcular_media_aparada(df, corte = 0)
  esperado <- (1 * 50 + 2 * 30 + 3 * 20) / 100
  expect_equal(resultado$nucleo_aparado, esperado, tolerance = 1e-9)
})

test_that("média aparada remove o efeito de um outlier de peso pequeno", {
  base <- data.frame(
    data = rep(as.Date("2026-08-01"), 10),
    item = letters[1:10],
    variacao = c(rep(0.4, 9), 30),
    peso = c(rep(11, 9), 1)
  )
  cheio <- sum(base$variacao * base$peso) / sum(base$peso)
  nucleo <- calcular_media_aparada(base, corte = 10)$nucleo_aparado
  expect_gt(cheio, nucleo)
  expect_equal(nucleo, 0.4, tolerance = 1e-9)
})

test_that("variação interanual usa média de período, não nível contra nível", {
  # Série com sazonalidade forte e nenhum crescimento real: a comparação por
  # média devolve 0, enquanto nível contra nível devolveria ruído sazonal.
  sazonal <- c(100, 90, 110, 95, 105, 100, 98, 102, 97, 103, 99, 101)
  df <- data.frame(
    data = seq(as.Date("2025-01-01"), by = "month", length.out = 24),
    valor = c(sazonal, sazonal)
  )
  expect_equal(variacao_interanual_media(df), 0, tolerance = 1e-9)
})

test_that("variação interanual capta crescimento real", {
  sazonal <- c(100, 90, 110, 95, 105, 100, 98, 102, 97, 103, 99, 101)
  df <- data.frame(
    data = seq(as.Date("2025-01-01"), by = "month", length.out = 24),
    valor = c(sazonal, sazonal * 1.05)
  )
  expect_equal(variacao_interanual_media(df), 5, tolerance = 1e-9)
})

test_that("variação interanual devolve NA sem janela completa", {
  df <- data.frame(data = seq(as.Date("2026-01-01"), by = "month", length.out = 6),
                   valor = rep(100, 6))
  expect_true(is.na(variacao_interanual_media(df)))
})

test_that("acumulado no ano compara os mesmos meses do ano anterior", {
  df <- data.frame(
    data = c(seq(as.Date("2025-01-01"), by = "month", length.out = 12),
             seq(as.Date("2026-01-01"), by = "month", length.out = 3)),
    valor = c(rep(100, 12), rep(110, 3))
  )
  # Jan-mar/2026 (média 110) contra jan-mar/2025 (média 100) = +10%.
  expect_equal(acumulado_no_ano_media(df, as.Date("2026-03-01")), 10, tolerance = 1e-9)
})

test_that("acumulado no ano não usa dezembro como base", {
  # Dezembro atípico: comparar contra ele daria -50%, o que o método antigo faria.
  df <- data.frame(
    data = c(seq(as.Date("2025-01-01"), by = "month", length.out = 12),
             as.Date("2026-01-01")),
    valor = c(rep(100, 11), 200, 100)
  )
  expect_equal(acumulado_no_ano_media(df, as.Date("2026-01-01")), 0, tolerance = 1e-9)
})

test_that("meta contínua conta meses consecutivos fora da banda", {
  df <- data.frame(
    data = seq(as.Date("2026-01-01"), by = "month", length.out = 8),
    acum_12m = c(4.8, 4.9, 3.2, 4.6, 4.7, 4.8, 4.9, 5.0)
  )
  resultado <- avaliar_meta_continua(df, meta = 3, banda = 1.5)
  expect_equal(resultado$fora_da_banda, c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE))
  # O contador zera em março e volta a subir a partir de abril.
  expect_equal(resultado$meses_consecutivos_fora, c(1, 2, 0, 1, 2, 3, 4, 5))
})

test_that("meta contínua trata o limite da banda como dentro", {
  df <- data.frame(data = as.Date("2026-01-01"), acum_12m = 4.5)
  expect_false(avaliar_meta_continua(df)$fora_da_banda)
})

test_that("contribuições somam o índice cheio", {
  df <- data.frame(
    data = rep(as.Date("2026-08-01"), 9),
    grupo = paste("grupo", 1:9),
    variacao = c(1, 0.5, -0.2, 0.3, 0.8, 0.1, 0.4, 0.2, -0.1),
    peso = c(20, 15, 5, 5, 20, 12, 10, 8, 5)
  )
  resultado <- preparar_contribuicoes(df)
  esperado <- sum(df$variacao * df$peso / 100)
  expect_equal(sum(resultado$mes_atual$contribuicao), esperado, tolerance = 1e-9)
})


# ── Camada de núcleos derivada do SIDRA ─────────────────────────────────

test_that("difusão por grupo aceita a saída de coletar_ipca_grupos", {
  source(file.path(rprojroot_raiz(), "R", "nucleos.R"))
  df <- data.frame(
    data = rep(as.Date("2026-08-01"), 9),
    grupo = paste("grupo", 1:9),
    variacao = c(1, 0.5, -0.2, 0.3, 0.8, 0.1, 0.4, -0.2, -0.1),
    peso = rep(100 / 9, 9)
  )
  resultado <- difusao_por_grupo(df)
  expect_equal(resultado$n_positivos, 6L)
  expect_equal(round(resultado$difusao, 2), round(600 / 9, 2))
})

test_that("média aparada por grupo neutraliza choque concentrado", {
  source(file.path(rprojroot_raiz(), "R", "nucleos.R"))
  # Um grupo de peso pequeno com alta de 15%; os demais estáveis em 0,3%.
  df <- data.frame(
    data = rep(as.Date("2026-08-01"), 9),
    grupo = paste("grupo", 1:9),
    variacao = c(rep(0.3, 8), 15),
    peso = c(rep(12, 8), 4)
  )
  cheio <- sum(df$variacao * df$peso) / sum(df$peso)
  nucleo <- media_aparada_por_grupo(df, corte = 20)$nucleo_aparado
  expect_gt(cheio, nucleo)
  expect_equal(nucleo, 0.3, tolerance = 1e-9)
})

test_that("consolidar_nucleos preserva uma linha por mês do IPCA", {
  source(file.path(rprojroot_raiz(), "R", "nucleos.R"))
  datas <- seq(as.Date("2026-06-01"), by = "month", length.out = 3)
  df_ipca <- data.frame(data = datas, ipca_mm = c(0.3, 0.2, 0.4))
  df_grupos <- do.call(rbind, lapply(datas, function(d) {
    data.frame(data = rep(d, 9), grupo = paste("g", 1:9),
               variacao = seq(-0.4, 0.4, length.out = 9), peso = rep(100 / 9, 9))
  }))
  resultado <- consolidar_nucleos(df_ipca, df_grupos)
  expect_equal(nrow(resultado), 3L)
  expect_true(all(c("ipca_mm", "nucleo_aparado", "difusao") %in% names(resultado)))
  expect_false(any(is.na(resultado$difusao)))
})

test_that("nenhum núcleo oficial é publicado sem confirmação explícita", {
  source(file.path(rprojroot_raiz(), "R", "nucleos.R"))
  # Guarda-chuva contra publicar série com rótulo não verificado: enquanto
  # NUCLEOS_SGS$confirmado for FALSE, a coleta devolve vazio em vez de arriscar.
  expect_true(all(c("chave", "codigo", "descricao", "confirmado") %in% names(NUCLEOS_SGS)))
  expect_type(NUCLEOS_SGS$confirmado, "logical")
})


# ── Coleta: funções puras, sem tocar a rede ─────────────────────────────

test_that("raiz_projeto encontra a raiz pelo _quarto.yml", {
  source(file.path(rprojroot_raiz(), "R", "coleta_sgs.R"))
  expect_true(file.exists(file.path(raiz_projeto(), "_quarto.yml")))
})

test_that("catálogo de séries declara janela para as séries diárias", {
  source(file.path(rprojroot_raiz(), "R", "coleta_sgs.R"))
  # A API SGS rejeita consulta a série diária sem filtro de data.
  diarias <- SERIES_SGS[SERIES_SGS$codigo %in% c(1L, 432L), ]
  expect_true(all(!is.na(diarias$janela_dias)))
  mensais <- SERIES_SGS[SERIES_SGS$codigo %in% c(433L, 24363L, 24364L), ]
  expect_true(all(is.na(mensais$janela_dias)))
})

# Linhas de código, sem comentários: o cabeçalho destes arquivos cita o código
# antigo como documentação do defeito, e não deve disparar o guarda.
codigo_de <- function(arquivo) {
  linhas <- readLines(file.path(rprojroot_raiz(), "R", arquivo), warn = FALSE)
  linhas[!grepl("^\\s*#", linhas)]
}

test_that("coleta não contém caminho absoluto nem data de referência fixa", {
  # Guarda contra a regressão que deixou "/home/runner/work/..." e
  # as.Date("2026-07-28") gravados no script de coleta.
  codigo <- codigo_de("coleta_sgs.R")
  expect_false(any(grepl("/home/runner", codigo, fixed = TRUE)))
  expect_false(any(grepl('data_ref *<- *as\\.Date\\("20', codigo)))
})

test_that("gerar_resumo não contém data de referência fixa", {
  codigo <- codigo_de("gerar_resumo.R")
  expect_false(any(grepl('gerar_resumo\\("20[0-9]{2}-', codigo)))
})

test_that("validar_e_limpar rejeita resposta de erro da API", {
  source(file.path(rprojroot_raiz(), "R", "coleta_sgs.R"))
  # O SGS às vezes devolve HTTP 200 com um objeto de erro no corpo.
  expect_null(validar_e_limpar(NULL, 433L))
  expect_null(validar_e_limpar(data.frame(), 433L))
  expect_null(validar_e_limpar(data.frame(erro = "x", mensagem = "y"), 433L))
})

test_that("validar_e_limpar normaliza para data e valor", {
  source(file.path(rprojroot_raiz(), "R", "coleta_sgs.R"))
  bruto <- data.frame(date = as.Date(c("2026-02-01", "2026-01-01")), `433` = c(0.4, 0.5),
                      check.names = FALSE)
  limpo <- validar_e_limpar(bruto, 433L)
  expect_equal(names(limpo), c("data", "valor"))
  expect_equal(limpo$data, as.Date(c("2026-01-01", "2026-02-01")))  # ordenado
  expect_equal(limpo$valor, c(0.5, 0.4))
})

test_that("validar_e_limpar rejeita série toda NA", {
  source(file.path(rprojroot_raiz(), "R", "coleta_sgs.R"))
  bruto <- data.frame(date = as.Date("2026-01-01"), `433` = NA_real_, check.names = FALSE)
  expect_null(validar_e_limpar(bruto, 433L))
})
