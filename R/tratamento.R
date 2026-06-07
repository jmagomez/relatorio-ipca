# Funções de tratamento e preparação dos dados do IPCA.
# Todas as funções são puras: recebem tibbles e retornam tibbles/listas
# sem efeitos colaterais.


# calcular_acumulado_12m -------------------------------------------------------

#' Acumulado em 12 meses do IPCA (janela móvel)
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm` (numeric), conforme
#'   retornado por [coletar_ipca_mensal()].
#' @return O mesmo tibble acrescido de `acumulado_12m` (em %; NA enquanto
#'   a janela de 12 meses não estiver completa).
calcular_acumulado_12m <- function(df) {
  df |>
    dplyr::arrange(data) |>
    dplyr::mutate(
      acumulado_12m = slider::slide_dbl(
        ipca_mm,
        ~ (prod(1 + .x / 100) - 1) * 100,
        .before   = 11,
        .complete = TRUE
      )
    )
}


# calcular_acumulado_ano -------------------------------------------------------

#' Acumulado no ano do IPCA (reinicia em janeiro)
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm` (numeric), conforme
#'   retornado por [coletar_ipca_mensal()].
#' @return O mesmo tibble acrescido de `acumulado_ano` (em %).
calcular_acumulado_ano <- function(df) {
  df |>
    dplyr::arrange(data) |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::group_by(ano) |>
    dplyr::mutate(
      acumulado_ano = (cumprod(1 + ipca_mm / 100) - 1) * 100
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-ano)
}


# preparar_sazonal -------------------------------------------------------------

#' Prepara série sazonal do IPCA para visualização por ano
#'
#' Filtra a série a partir de `ano_inicio`, decompõe em `mes` e `ano`,
#' e atribui uma cor a cada ano — cinzas para os históricos, #282f6b
#' para o ano corrente.
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm` (numeric).
#' @param ano_inicio Primeiro ano a incluir (padrão: 2015).
#' @return Tibble com colunas `mes` (int), `ano` (int), `ipca_mm` (numeric),
#'   `cor` (character hex), `destaque` (logical).
preparar_sazonal <- function(df, ano_inicio = 2015) {
  ano_atual <- lubridate::year(max(df$data, na.rm = TRUE))

  dados <- df |>
    dplyr::filter(lubridate::year(data) >= ano_inicio) |>
    dplyr::mutate(
      mes = lubridate::month(data),
      ano = lubridate::year(data)
    ) |>
    dplyr::select(mes, ano, ipca_mm)

  anos_hist  <- sort(setdiff(unique(dados$ano), ano_atual))
  n_hist     <- length(anos_hist)
  cores_hist <- if (n_hist > 0) {
    grDevices::colorRampPalette(c("#d0d0d0", "#909090"))(n_hist)
  } else {
    character(0)
  }
  cores_map <- stats::setNames(
    c(cores_hist, "#282f6b"),
    c(anos_hist,  ano_atual)
  )

  dados |>
    dplyr::mutate(
      cor      = cores_map[as.character(ano)],
      destaque = ano == ano_atual
    )
}


# preparar_contribuicoes -------------------------------------------------------

#' Calcula contribuições dos grupos ao IPCA
#'
#' Contribuição de cada grupo = `variacao * peso / 100`. A soma das
#' contribuições dos 9 grupos deve reproduzir o IPCA cheio do mês
#' (coluna `soma_contrib` em `soma_mensal` serve de sanity check contra
#' a série 433).
#'
#' @param df_grupos Tibble com colunas `data`, `grupo`, `variacao`, `peso`,
#'   conforme retornado por [coletar_ipca_grupos()].
#' @return Lista com três elementos:
#'   \describe{
#'     \item{historico}{Série completa com coluna `contribuicao` adicionada.}
#'     \item{mes_atual}{Recorte do último mês disponível.}
#'     \item{soma_mensal}{Tibble com `data`, `n_grupos`, `soma_contrib` —
#'       compare `soma_contrib` com o IPCA cheio (série 433) para validar.}
#'   }
preparar_contribuicoes <- function(df_grupos) {
  historico <- df_grupos |>
    dplyr::arrange(data, grupo) |>
    dplyr::mutate(contribuicao = variacao * peso / 100)

  soma_mensal <- historico |>
    dplyr::group_by(data) |>
    dplyr::summarise(
      n_grupos     = dplyr::n(),
      soma_contrib = sum(contribuicao, na.rm = TRUE),
      .groups      = "drop"
    )

  meses_incompletos <- dplyr::filter(soma_mensal, n_grupos != 9)
  if (nrow(meses_incompletos) > 0) {
    warning(
      nrow(meses_incompletos),
      " mês(es) com número de grupos diferente de 9; verificar dados.",
      call. = FALSE
    )
  }

  data_atual <- max(historico$data, na.rm = TRUE)

  list(
    historico   = historico,
    mes_atual   = dplyr::filter(historico, data == data_atual),
    soma_mensal = soma_mensal
  )
}


# preparar_meta_mensal ---------------------------------------------------------

#' Expande a meta anual de inflação para frequência mensal
#'
#' A série 13521 do BCB fornece a meta por ano-calendário. Esta função
#' propaga a meta para cada mês via join por ano.
#'
#' @param df_ipca Tibble com coluna `data` (Date) e demais colunas da série
#'   mensal, conforme retornado por [coletar_ipca_mensal()].
#' @param df_meta Tibble com colunas `data` (Date) e `meta` (numeric),
#'   conforme retornado por [coletar_meta_inflacao()].
#' @return Tibble com todas as colunas de `df_ipca` mais `meta` (numeric).
preparar_meta_mensal <- function(df_ipca, df_meta) {
  meta_anual <- df_meta |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::select(ano, meta)

  df_ipca |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::left_join(meta_anual, by = "ano") |>
    dplyr::select(-ano)
}
