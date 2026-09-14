# Gera output/dados/resumo.csv a partir das séries brutas em output/dados/.
#
# Lê ipca.csv, cambio.csv, selic.csv, ibcbr.csv (original, SGS 24363) e
# ibcbr_sa.csv (ajuste sazonal, SGS 24364), calcula as variações do
# Boletim Macro Semanal e grava o resumo de 4 linhas (uma por indicador).
#
# Convenções:
# - IPCA: var_ano e var_12m via produtório composto (calcular_acumulado_ano/
#   calcular_acumulado_12m de R/tratamento.R); var_mes replica o valor_atual
#   (a própria variação mensal do IPCA).
# - Câmbio e Selic: variações comparam o último nível disponível na data de
#   referência com o último nível disponível em (ref - 1 mês), no fechamento
#   do ano anterior (31/12) e em (ref - 1 ano). Câmbio em variação percentual
#   entre níveis; Selic em pontos percentuais (diferença simples).
# - IBC-Br: valor_atual e data_ref vêm da série original (24363); var_mes vem
#   da série com ajuste sazonal (24364, mês vs mês anterior); var_ano e
#   var_12m vêm da série original (24363), por média de período.
#
# Falhas são isoladas por série (tryCatch): um problema em uma fonte não
# impede o cálculo das demais. Campos não calculáveis recebem NA — a linha
# do indicador nunca é omitida.

library(dplyr)
library(lubridate)

diretorio_script <- tryCatch(
  dirname(sys.frame(1)$ofile),
  error = function(e) NA_character_
)
if (is.na(diretorio_script) || diretorio_script == "") {
  diretorio_script <- "R"
}
source(file.path(diretorio_script, "tratamento.R"))

DIR_DADOS <- "output/dados"

#' Lê um CSV de série temporal (colunas `data`, `valor`)
ler_serie <- function(caminho) {
  df <- utils::read.csv(caminho, stringsAsFactors = FALSE)
  df$data <- as.Date(df$data)
  df$valor <- as.numeric(df$valor)
  dplyr::arrange(df, data)
}

#' Último valor observado em `data` <= `alvo` (ou NA se não houver)
valor_em_ou_antes <- function(df, alvo) {
  sub <- df[!is.na(df$data) & df$data <= alvo, ]
  if (nrow(sub) == 0L) return(NA_real_)
  sub <- sub[order(sub$data), ]
  dplyr::last(sub$valor)
}

#' Data do último valor observado em `data` <= `alvo` (ou NA se não houver)
data_em_ou_antes <- function(df, alvo) {
  sub <- df[!is.na(df$data) & df$data <= alvo, ]
  if (nrow(sub) == 0L) return(as.Date(NA))
  sub <- sub[order(sub$data), ]
  dplyr::last(sub$data)
}

#' Variação percentual entre dois níveis: (atual / referencia - 1) * 100
variacao_pct <- function(atual, referencia) {
  if (is.na(atual) || is.na(referencia) || referencia == 0) return(NA_real_)
  (atual / referencia - 1) * 100
}

#' Diferença simples em pontos (para Selic): atual - referencia
variacao_pp <- function(atual, referencia) {
  if (is.na(atual) || is.na(referencia)) return(NA_real_)
  atual - referencia
}

linha_na <- function(indicador, unidade) {
  data.frame(
    indicador = indicador, unidade = unidade,
    valor_atual = NA_real_, data_ref = NA_character_,
    var_mes = NA_real_, var_ano = NA_real_, var_12m = NA_real_,
    stringsAsFactors = FALSE
  )
}

# --------------------------------------------------------------------------
# IPCA (SGS 433) — var_mes replica a variação mensal; var_ano e var_12m via
# produtório composto sobre a série de variações mensais.
# --------------------------------------------------------------------------
calcular_ipca <- function() {
  df <- ler_serie(file.path(DIR_DADOS, "ipca.csv")) |>
    dplyr::rename(ipca_mm = valor)

  df <- calcular_acumulado_ano(df)
  df <- calcular_acumulado_12m(df)

  ultimo <- dplyr::filter(df, !is.na(ipca_mm))
  ultimo <- dplyr::filter(ultimo, data == max(data))

  data.frame(
    indicador = "IPCA", unidade = "%",
    valor_atual = round(ultimo$ipca_mm, 2),
    data_ref = as.character(ultimo$data),
    var_mes = round(ultimo$ipca_mm, 2),
    var_ano = round(ultimo$acum_ano, 2),
    var_12m = round(ultimo$acum_12m, 2),
    stringsAsFactors = FALSE
  )
}

# --------------------------------------------------------------------------
# Câmbio R$/US$ (SGS 1) — variação percentual entre níveis
# --------------------------------------------------------------------------
calcular_cambio <- function(ref_date) {
  df <- ler_serie(file.path(DIR_DADOS, "cambio.csv"))

  data_ref <- data_em_ou_antes(df, ref_date)
  valor_atual <- valor_em_ou_antes(df, ref_date)

  alvo_mes  <- ref_date %m-% months(1)
  alvo_ano  <- as.Date(sprintf("%d-12-31", lubridate::year(ref_date) - 1))
  alvo_12m  <- ref_date %m-% years(1)

  valor_mes <- valor_em_ou_antes(df, alvo_mes)
  valor_ano <- valor_em_ou_antes(df, alvo_ano)
  valor_12m <- valor_em_ou_antes(df, alvo_12m)

  data.frame(
    indicador = "Cambio R$/US$", unidade = "R$",
    valor_atual = round(valor_atual, 2),
    data_ref = as.character(data_ref),
    var_mes = round(variacao_pct(valor_atual, valor_mes), 2),
    var_ano = round(variacao_pct(valor_atual, valor_ano), 2),
    var_12m = round(variacao_pct(valor_atual, valor_12m), 2),
    stringsAsFactors = FALSE
  )
}

# --------------------------------------------------------------------------
# Selic meta (SGS 432) — diferença em pontos percentuais
# --------------------------------------------------------------------------
calcular_selic <- function(ref_date) {
  df <- ler_serie(file.path(DIR_DADOS, "selic.csv"))

  data_ref <- data_em_ou_antes(df, ref_date)
  valor_atual <- valor_em_ou_antes(df, ref_date)

  alvo_mes <- ref_date %m-% months(1)
  alvo_ano <- as.Date(sprintf("%d-12-31", lubridate::year(ref_date) - 1))
  alvo_12m <- ref_date %m-% years(1)

  valor_mes <- valor_em_ou_antes(df, alvo_mes)
  valor_ano <- valor_em_ou_antes(df, alvo_ano)
  valor_12m <- valor_em_ou_antes(df, alvo_12m)

  data.frame(
    indicador = "Selic meta", unidade = "p.p.",
    valor_atual = round(valor_atual, 2),
    data_ref = as.character(data_ref),
    var_mes = round(variacao_pp(valor_atual, valor_mes), 2),
    var_ano = round(variacao_pp(valor_atual, valor_ano), 2),
    var_12m = round(variacao_pp(valor_atual, valor_12m), 2),
    stringsAsFactors = FALSE
  )
}

# --------------------------------------------------------------------------
# IBC-Br — valor_atual/data_ref e var_ano/var_12m da série original (24363);
# var_mes da série com ajuste sazonal (24364)
# --------------------------------------------------------------------------
calcular_ibcbr <- function(ref_date) {
  original <- ler_serie(file.path(DIR_DADOS, "ibcbr.csv"))
  sa       <- ler_serie(file.path(DIR_DADOS, "ibcbr_sa.csv"))

  data_ref    <- data_em_ou_antes(original, ref_date)
  valor_atual <- valor_em_ou_antes(original, ref_date)

  # var_mes: série COM ajuste sazonal (24364), mês contra mês anterior. É a
  # única comparação ponto a ponto legítima, porque a série já está
  # dessazonalizada.
  sa_atual    <- valor_em_ou_antes(sa, data_ref)
  sa_mes_ref  <- valor_em_ou_antes(sa, data_ref %m-% months(1))

  # var_ano e var_12m: série ORIGINAL (24363), por **média de período**.
  #
  # Correção de um erro do cálculo anterior. Antes, `var_ano` comparava o nível
  # do índice sem ajuste sazonal contra o nível de 31/dez do ano anterior, e
  # `var_12m` comparava nível contra nível doze meses antes. Índice de volume
  # bruto carrega sazonalidade: a diferença entre dois meses mede tanto o
  # crescimento quanto a diferença sazonal entre eles, e um dezembro atípico
  # contamina o ano inteiro. "Acumulado no ano" e "variação em 12 meses" de
  # índice de volume são definidos pelo IBGE e pelo BCB como comparação entre
  # **médias** de períodos correspondentes.
  serie_original <- original[, c("data", "valor")]

  data.frame(
    indicador = "IBC-Br", unidade = "indice",
    valor_atual = round(valor_atual, 2),
    data_ref = as.character(data_ref),
    var_mes = round(variacao_pct(sa_atual, sa_mes_ref), 2),
    var_ano = round(acumulado_no_ano_media(serie_original, data_ref), 2),
    var_12m = round(variacao_interanual_media(serie_original, data_ref, n = 12L), 2),
    stringsAsFactors = FALSE
  )
}

#' Monta o resumo completo (4 linhas), isolando falhas por indicador
gerar_resumo <- function(ref_date = Sys.Date()) {
  ref_date <- as.Date(ref_date)

  ipca <- tryCatch(calcular_ipca(), error = function(e) {
    warning("Falha ao calcular IPCA: ", conditionMessage(e))
    linha_na("IPCA", "%")
  })
  cambio <- tryCatch(calcular_cambio(ref_date), error = function(e) {
    warning("Falha ao calcular Cambio: ", conditionMessage(e))
    linha_na("Cambio R$/US$", "R$")
  })
  selic <- tryCatch(calcular_selic(ref_date), error = function(e) {
    warning("Falha ao calcular Selic: ", conditionMessage(e))
    linha_na("Selic meta", "p.p.")
  })
  ibcbr <- tryCatch(calcular_ibcbr(ref_date), error = function(e) {
    warning("Falha ao calcular IBC-Br: ", conditionMessage(e))
    linha_na("IBC-Br", "indice")
  })

  dplyr::bind_rows(ipca, cambio, selic, ibcbr)
}

#' Formata colunas numéricas com 2 casas decimais fixas (preserva NA como
#' texto "NA"), replicando o estilo do resumo.csv já publicado.
formatar_csv <- function(df) {
  cols_num <- c("valor_atual", "var_mes", "var_ano", "var_12m")
  for (col in cols_num) {
    df[[col]] <- ifelse(
      is.na(df[[col]]), "NA",
      formatC(df[[col]], format = "f", digits = 2)
    )
  }
  df
}

# Execução como script: `Rscript R/gerar_resumo.R [AAAA-MM-DD]`.
# A data de referência vem do argumento de linha de comando, nunca fixa no
# código — a versão anterior carregava "2026-07-28" gravado aqui, o que fazia
# toda execução posterior recalcular o resumo de uma data antiga.
if (identical(environment(), globalenv()) && sys.nframe() == 0L) {
  argumentos <- commandArgs(trailingOnly = TRUE)
  ref <- if (length(argumentos) >= 1L && nzchar(argumentos[1])) {
    as.Date(argumentos[1])
  } else {
    Sys.Date()
  }
  message("Gerando resumo com data de referência ", ref)
  resumo <- gerar_resumo(ref)
  utils::write.csv(
    formatar_csv(resumo), file.path(DIR_DADOS, "resumo.csv"),
    row.names = FALSE, quote = FALSE
  )
}
