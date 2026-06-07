# Funções de coleta de dados: IPCA mensal, meta de inflação e IPCA por grupos.
# Fontes: API do BCB via rbcb (séries 433 e 13521) e SIDRA/IBGE via sidrar
# (tabela 7060).

#' Coleta a série mensal do IPCA (série 433) via BCB
#'
#' Consulta a API do Banco Central do Brasil e retorna a variação percentual
#' mensal do IPCA desde o início da série disponível.
#'
#' @return Tibble com colunas:
#'   \describe{
#'     \item{data}{Data de referência (`Date`, último dia útil do mês).}
#'     \item{ipca_mm}{Variação percentual mensal do IPCA (`numeric`).}
#'   }
#' @examples
#' \dontrun{
#' coletar_ipca_mensal()
#' }
coletar_ipca_mensal <- function() {
  rbcb::get_series(433) |>
    dplyr::rename(data = date, ipca_mm = `433`)
}


#' Coleta a meta de inflação (série 13521) via BCB
#'
#' Consulta a API do Banco Central do Brasil e retorna a meta de inflação
#' estabelecida pelo Conselho Monetário Nacional (CMN) para cada ano.
#'
#' @return Tibble com colunas:
#'   \describe{
#'     \item{data}{Data de referência (`Date`).}
#'     \item{meta}{Meta de inflação em pontos percentuais (`numeric`).}
#'   }
#' @examples
#' \dontrun{
#' coletar_meta_inflacao()
#' }
coletar_meta_inflacao <- function() {
  rbcb::get_series(13521) |>
    dplyr::rename(data = date, meta = `13521`)
}


#' Coleta o IPCA por grupos (tabela 7060) via SIDRA/IBGE
#'
#' Realiza duas consultas à tabela 7060 do SIDRA: variável 63 (variação
#' percentual mensal) e variável 66 (peso relativo no índice). A classificação
#' c315 é filtrada nos nove grupos do IPCA. Toda a série histórica disponível
#' é retornada.
#'
#' Grupos consultados (códigos c315):
#' 7170 Alimentação e bebidas, 7445 Habitação, 7486 Artigos de residência,
#' 7558 Vestuário, 7625 Transportes, 7660 Saúde e cuidados pessoais,
#' 7712 Despesas pessoais, 7766 Educação, 7786 Comunicação.
#'
#' @return Tibble com colunas:
#'   \describe{
#'     \item{data}{Data de referência (`Date`, primeiro dia do mês).}
#'     \item{grupo}{Nome do grupo conforme nomenclatura do IBGE (`character`).}
#'     \item{variacao}{Variação percentual mensal do grupo (`numeric`).}
#'     \item{peso}{Peso relativo do grupo no índice cheio (`numeric`).}
#'   }
#' @examples
#' \dontrun{
#' coletar_ipca_grupos()
#' }
coletar_ipca_grupos <- function() {
  grupos_c315 <- c(7170, 7445, 7486, 7558, 7625, 7660, 7712, 7766, 7786)

  # Coluna de classificação retornada pelo sidrar para c315
  col_grupo <- "Geral, grupo, subgrupo, item e subitem"

  buscar_variavel <- function(variavel) {
    sidrar::get_sidra(
      x         = 7060,
      variable  = variavel,
      classific = "c315",
      category  = list("315" = grupos_c315),
      period    = c(last = 600),
      geo       = "Brazil"
    ) |>
      dplyr::select(
        periodo = `Mês (Código)`,
        grupo   = dplyr::all_of(col_grupo),
        valor   = Valor
      ) |>
      dplyr::mutate(
        data  = as.Date(paste0(periodo, "01"), format = "%Y%m%d"),
        valor = as.numeric(valor)
      ) |>
      dplyr::select(data, grupo, valor)
  }

  variacao <- buscar_variavel(63)
  peso     <- buscar_variavel(66)

  dplyr::inner_join(variacao, peso, by = c("data", "grupo")) |>
    dplyr::rename(variacao = valor.x, peso = valor.y) |>
    dplyr::arrange(data, grupo)
}
