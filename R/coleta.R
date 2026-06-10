# Funções de coleta de dados macroeconômicos via rbcb e sidrar

library(rbcb)
library(sidrar)
library(dplyr)
library(tidyr)
library(lubridate)

#' Coleta a série mensal do IPCA (variação % mensal)
#'
#' Obtém a série 433 do Banco Central do Brasil, que representa a variação
#' percentual mensal do IPCA apurada pelo IBGE.
#'
#' @param data_inicio Data de início da série no formato "YYYY-MM-DD".
#'   Padrão: "1980-01-01".
#' @param data_fim Data de fim da série no formato "YYYY-MM-DD".
#'   Padrão: data de hoje.
#'
#' @return Tibble com colunas:
#'   \describe{
#'     \item{data}{Data de referência (primeiro dia do mês).}
#'     \item{ipca_mm}{Variação percentual mensal do IPCA.}
#'   }
coletar_ipca_mensal <- function(
    data_inicio = "1980-01-01",
    data_fim    = Sys.Date()) {

  rbcb::get_series(
    code       = 433,
    start_date = data_inicio,
    end_date   = data_fim
  ) |>
    dplyr::rename(ipca_mm = `433`) |>
    dplyr::mutate(data = as.Date(date)) |>
    dplyr::select(data, ipca_mm)
}


#' Coleta a série de meta de inflação (IPCA acumulado 12 meses)
#'
#' Obtém a série 13521 do Banco Central do Brasil, que corresponde à meta
#' para a inflação definida pelo CMN para o ano calendário.
#'
#' @param data_inicio Data de início da série no formato "YYYY-MM-DD".
#'   Padrão: "2000-01-01".
#' @param data_fim Data de fim da série no formato "YYYY-MM-DD".
#'   Padrão: data de hoje.
#'
#' @return Tibble com colunas:
#'   \describe{
#'     \item{data}{Data de referência (primeiro dia do mês).}
#'     \item{meta_inflacao}{Meta de inflação vigente para o período (% a.a.).}
#'   }
coletar_meta_inflacao <- function(
    data_inicio = "2000-01-01",
    data_fim    = Sys.Date()) {

  rbcb::get_series(
    code       = 13521,
    start_date = data_inicio,
    end_date   = data_fim
  ) |>
    dplyr::rename(meta_inflacao = `13521`) |>
    dplyr::mutate(data = as.Date(date)) |>
    dplyr::select(data, meta_inflacao)
}


#' Coleta IPCA por grupos: variação mensal e peso na cesta (tabela SIDRA 7060)
#'
#' Realiza duas chamadas à API do SIDRA (IBGE): uma para a variação mensal
#' (variável 63) e outra para o peso de cada grupo na cesta do IPCA (variável
#' 66), ambas para os 9 grupos do IPCA na classificação c315. Os resultados são
#' combinados em um único tibble no formato tidy, cobrindo toda a série histórica
#' disponível.
#'
#' Grupos coletados (códigos c315):
#'   7170 - Alimentação e bebidas
#'   7445 - Habitação
#'   7486 - Artigos de residência
#'   7558 - Vestuário
#'   7625 - Transportes
#'   7660 - Saúde e cuidados pessoais
#'   7712 - Despesas pessoais
#'   7766 - Educação
#'   7786 - Comunicação
#'
#' @return Tibble com colunas:
#'   \describe{
#'     \item{data}{Data de referência (primeiro dia do mês).}
#'     \item{grupo}{Nome do grupo de despesa.}
#'     \item{variacao}{Variação percentual mensal do grupo (variável 63).}
#'     \item{peso}{Peso percentual do grupo na cesta do IPCA (variável 66).}
#'   }
coletar_ipca_grupos <- function() {

  codigos_grupos <- c(7170, 7445, 7486, 7558, 7625, 7660, 7712, 7766, 7786)

  # Variação mensal por grupo (variável 63)
  variacao_raw <- sidrar::get_sidra(
    x        = 7060,
    variable = 63,
    period   = "all",
    classific = "c315",
    category  = list(c315 = codigos_grupos),
    geo       = "Brazil"
  )

  # Peso do grupo na cesta (variável 66)
  peso_raw <- sidrar::get_sidra(
    x        = 7060,
    variable = 66,
    period   = "all",
    classific = "c315",
    category  = list(c315 = codigos_grupos),
    geo       = "Brazil"
  )

  col_grupo <- "Geral, grupo, subgrupo, item e subitem"

  limpar <- function(df, novo_nome) {
    df |>
      dplyr::select(
        periodo = `Mês (Código)`,
        grupo   = dplyr::all_of(col_grupo),
        valor   = `Valor`
      ) |>
      dplyr::mutate(
        data  = lubridate::ym(periodo),
        valor = as.numeric(valor)
      ) |>
      dplyr::select(data, grupo, !!novo_nome := valor)
  }

  df_variacao <- limpar(variacao_raw, "variacao")
  df_peso     <- limpar(peso_raw,     "peso")

  dplyr::inner_join(df_variacao, df_peso, by = c("data", "grupo")) |>
    dplyr::arrange(data, grupo)
}
