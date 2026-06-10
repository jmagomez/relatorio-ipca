# Funções puras de tratamento e preparação dos dados do IPCA

library(dplyr)
library(tidyr)
library(lubridate)
library(slider)

#' Calcula o IPCA acumulado em 12 meses via janela móvel
#'
#' Aplica a fórmula de capitalização composta sobre uma janela deslizante de
#' 12 observações mensais: (prod(1 + x_i/100) - 1) * 100.
#' Os primeiros 11 meses recebem NA por janela incompleta.
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm` (variação % mensal).
#' @return O mesmo tibble com coluna adicional `acum_12m` (%).
calcular_acumulado_12m <- function(df) {
  df |>
    dplyr::arrange(data) |>
    dplyr::mutate(
      acum_12m = slider::slide_dbl(
        ipca_mm,
        .f        = ~ (prod(1 + .x / 100) - 1) * 100,
        .before   = 11,
        .complete = TRUE
      )
    )
}


#' Calcula o IPCA acumulado no ano calendário
#'
#' Reinicia o acúmulo em janeiro de cada ano. Para cada mês, retorna o
#' produto encadeado de todos os meses anteriores do mesmo ano, inclusive
#' o próprio mês: (cumprod(1 + x_i/100) - 1) * 100.
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm` (variação % mensal).
#' @return O mesmo tibble com coluna adicional `acum_ano` (%).
calcular_acumulado_ano <- function(df) {
  df |>
    dplyr::arrange(data) |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::group_by(ano) |>
    dplyr::mutate(
      acum_ano = (cumprod(1 + ipca_mm / 100) - 1) * 100
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-ano)
}


#' Prepara dados para o gráfico sazonal (sobreposição de anos)
#'
#' Extrai mês e ano de cada observação e marca o ano mais recente como
#' destaque. A coluna `ano` retornada como fator ordenado permite que o
#' ggplot2 mapeie cores automaticamente, reservando a camada de destaque
#' para o ano corrente.
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm`.
#' @param ano_inicio Primeiro ano a incluir na série. Padrão: 2015.
#' @return Tibble com colunas `mes` (int 1–12), `ano` (fator ordenado),
#'   `ipca_mm` e `destaque` (logical TRUE para o ano mais recente).
preparar_sazonal <- function(df, ano_inicio = 2015) {
  ano_corrente <- lubridate::year(max(df$data, na.rm = TRUE))

  df |>
    dplyr::filter(lubridate::year(data) >= ano_inicio) |>
    dplyr::mutate(
      mes      = lubridate::month(data),
      ano      = lubridate::year(data),
      destaque = ano == ano_corrente,
      ano      = factor(ano, levels = sort(unique(ano)), ordered = TRUE)
    ) |>
    dplyr::select(mes, ano, ipca_mm, destaque)
}


#' Calcula contribuições de cada grupo do IPCA para a variação mensal
#'
#' A contribuição de cada grupo é definida como:
#'   contribuicao = variacao * peso / 100
#'
#' A soma das 9 contribuições reproduz o IPCA cheio do mês. Emite aviso
#' caso qualquer mês apresente menos de 9 grupos (dados incompletos).
#'
#' Para validar a coerência, compare `sum(contribuicao)` por mês com
#' `ipca_mm` obtido via `coletar_ipca_mensal()`.
#'
#' @param df_grupos Tibble com colunas `data` (Date), `grupo` (chr),
#'   `variacao` (num) e `peso` (num), conforme retornado por
#'   `coletar_ipca_grupos()`.
#' @return Lista com dois elementos:
#'   \describe{
#'     \item{historico}{Tibble completo com coluna `contribuicao` adicionada.}
#'     \item{mes_atual}{Recorte do mês mais recente disponível.}
#'   }
preparar_contribuicoes <- function(df_grupos) {
  historico <- df_grupos |>
    dplyr::mutate(contribuicao = variacao * peso / 100)

  # sanity check: todo mês deve ter os 9 grupos
  contagem <- historico |>
    dplyr::group_by(data) |>
    dplyr::summarise(n_grupos = dplyr::n(), .groups = "drop")

  meses_incompletos <- sum(contagem$n_grupos < 9L, na.rm = TRUE)
  if (meses_incompletos > 0L) {
    warning(sprintf(
      paste0(
        "%d mês(es) com menos de 9 grupos. ",
        "A soma das contribuições ficará subestimada nesses períodos."
      ),
      meses_incompletos
    ))
  }

  data_atual <- max(historico$data, na.rm = TRUE)
  mes_atual  <- dplyr::filter(historico, data == data_atual)

  list(historico = historico, mes_atual = mes_atual)
}


#' Expande a meta anual de inflação para frequência mensal
#'
#' A série 13521 do BCB fornece a meta em base anual. Esta função junta os
#' dados com o calendário mensal do IPCA pelo ano, de modo que cada mês
#' receba a meta vigente no seu ano calendário. Meses de anos sem meta
#' cadastrada recebem NA.
#'
#' Quando a série 13521 retorna múltiplos registros para o mesmo ano
#' (revisões intra-anuais), é mantido o valor mais recente.
#'
#' @param df_ipca Tibble com ao menos a coluna `data` (Date), conforme
#'   retornado por `coletar_ipca_mensal()`.
#' @param df_meta Tibble com colunas `data` (Date) e `meta_inflacao`,
#'   conforme retornado por `coletar_meta_inflacao()`.
#' @return Tibble com todas as colunas de `df_ipca` mais `meta_inflacao`.
preparar_meta_mensal <- function(df_ipca, df_meta) {
  meta_por_ano <- df_meta |>
    dplyr::arrange(data) |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::group_by(ano) |>
    dplyr::summarise(meta_inflacao = dplyr::last(meta_inflacao), .groups = "drop")

  df_ipca |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::left_join(meta_por_ano, by = "ano") |>
    dplyr::select(-ano)
}
