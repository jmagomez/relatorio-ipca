# Funções de visualização do IPCA.
# Todas retornam objetos ggplot prontos para exibição ou composição com patchwork.
# Paleta: #282f6b (azul), #d97706 (âmbar), #059669 (verde), #6b7280 (cinza).

.meses_pt <- c("Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
               "Jul", "Ago", "Set", "Out", "Nov", "Dez")

.tema_base <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.caption     = ggplot2::element_text(color = "#6b7280", size = 8)
    )
}


# grafico_ipca_mensal ----------------------------------------------------------

#' Barras: variação mensal do IPCA (últimos 24 meses)
#'
#' Eixo y truncado ao intervalo dos dados (coord_cartesian), com rótulos
#' numéricos e o valor de cada barra anotado via geom_text.
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm` (numeric), conforme
#'   retornado por [coletar_ipca_mensal()].
#' @return Objeto ggplot.
grafico_ipca_mensal <- function(df) {
  dados <- df |>
    dplyr::arrange(data) |>
    dplyr::slice_tail(n = 24) |>
    dplyr::mutate(
      cor   = dplyr::if_else(ipca_mm >= 0, "#282f6b", "#d97706"),
      vjust = dplyr::if_else(ipca_mm >= 0, -0.35, 1.35),
      label = scales::number(ipca_mm, accuracy = 0.01, decimal.mark = ",")
    )

  y_min <- ifelse(
    min(dados$ipca_mm, na.rm = TRUE) >= 0,
    0,
    min(dados$ipca_mm, na.rm = TRUE) * 1.40
  )
  y_max <- max(dados$ipca_mm, na.rm = TRUE) * 1.30  # margem para rótulos

  ggplot2::ggplot(dados, ggplot2::aes(x = data, y = ipca_mm)) +
    ggplot2::geom_col(ggplot2::aes(fill = cor), width = 20) +
    ggplot2::geom_text(
      ggplot2::aes(label = label, vjust = vjust),
      size  = 2.9,
      color = "#1a1a1a"
    ) +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_x_date(
      date_breaks = "3 months",
      date_labels = "%b\n%Y",
      expand      = ggplot2::expansion(add = 30)
    ) +
    ggplot2::scale_y_continuous(
      labels = ~ scales::number(.x, decimal.mark = ","),
      expand = ggplot2::expansion(mult = 0)
    ) +
    ggplot2::coord_cartesian(ylim = c(y_min, y_max)) +
    ggplot2::labs(
      x       = NULL,
      y       = "Variação mensal (%)",
      title   = "IPCA — Variação mensal",
      caption = "Fonte: BCB (série 433)"
    ) +
    .tema_base()
}


# grafico_ipca_12m -------------------------------------------------------------

#' Linha: IPCA acumulado em 12 meses com meta variável e banda de tolerância
#'
#' A meta é expandida para frequência mensal via join por ano. A banda de
#' tolerância é meta ± 1,5 p.p. O último valor é destacado por uma caixa
#' no canto superior direito.
#'
#' @param df Tibble com colunas `data` (Date) e `acumulado_12m` (numeric),
#'   conforme retornado por [calcular_acumulado_12m()].
#' @param df_meta Tibble com colunas `data` (Date) e `meta` (numeric),
#'   conforme retornado por [coletar_meta_inflacao()].
#' @return Objeto ggplot.
grafico_ipca_12m <- function(df, df_meta) {
  meta_anual <- df_meta |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::select(ano, meta)

  dados <- df |>
    dplyr::filter(!is.na(acumulado_12m)) |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::left_join(meta_anual, by = "ano") |>
    dplyr::select(-ano)

  ultimo_valor <- dplyr::slice_tail(dados, n = 1)$acumulado_12m
  rotulo_box   <- scales::number(
    ultimo_valor,
    accuracy     = 0.01,
    decimal.mark = ",",
    suffix       = "%"
  )

  ggplot2::ggplot(dados, ggplot2::aes(x = data)) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = meta - 1.5, ymax = meta + 1.5),
      fill  = "#6b7280",
      alpha = 0.15
    ) +
    ggplot2::geom_line(
      ggplot2::aes(y = meta),
      color     = "#059669",
      linetype  = "dashed",
      linewidth = 0.65
    ) +
    ggplot2::geom_line(
      ggplot2::aes(y = acumulado_12m),
      color     = "#282f6b",
      linewidth = 1
    ) +
    ggplot2::annotate(
      "label",
      x             = Inf,
      y             = Inf,
      label         = paste0("12m: ", rotulo_box),
      hjust         = 1.05,
      vjust         = 1.4,
      size          = 3.5,
      fill          = "#282f6b",
      color         = "white",
      label.padding = ggplot2::unit(0.35, "lines"),
      label.size    = 0,
      label.r       = ggplot2::unit(0.25, "lines")
    ) +
    ggplot2::scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
    ggplot2::scale_y_continuous(
      labels = ~ scales::number(.x, decimal.mark = ",", suffix = "%")
    ) +
    ggplot2::labs(
      x       = NULL,
      y       = "% a.a.",
      title   = "IPCA acumulado em 12 meses",
      subtitle = "Banda cinza: meta ± 1,5 p.p.  |  Tracejado verde: meta",
      caption  = "Fonte: BCB (séries 433 e 13521)"
    ) +
    .tema_base()
}


# grafico_sazonal --------------------------------------------------------------

#' Linhas sazonais: um traço por ano, ano atual destacado
#'
#' As cores por ano são lidas diretamente da coluna `cor` via
#' scale_color_identity, com legenda gerada a partir dos valores únicos.
#' O ano corrente recebe linha mais espessa (linewidth = 1,2).
#'
#' @param df_saz Tibble conforme retornado por [preparar_sazonal()], com
#'   colunas `mes` (int), `ano` (int), `ipca_mm` (numeric),
#'   `cor` (character hex) e `destaque` (logical).
#' @return Objeto ggplot.
grafico_sazonal <- function(df_saz) {
  cores_por_ano <- df_saz |>
    dplyr::distinct(ano, cor) |>
    dplyr::arrange(ano)

  ggplot2::ggplot(
    df_saz,
    ggplot2::aes(
      x         = mes,
      y         = ipca_mm,
      color     = cor,
      group     = ano,
      linewidth = destaque
    )
  ) +
    ggplot2::geom_line(lineend = "round") +
    ggplot2::scale_color_identity(
      name   = "Ano",
      guide  = ggplot2::guide_legend(
        override.aes = list(linewidth = 1),
        ncol         = 2
      ),
      breaks = cores_por_ano$cor,
      labels = cores_por_ano$ano
    ) +
    ggplot2::scale_linewidth_manual(
      values = c("FALSE" = 0.4, "TRUE" = 1.2),
      guide  = "none"
    ) +
    ggplot2::scale_x_continuous(
      breaks = 1:12,
      labels = .meses_pt,
      expand = ggplot2::expansion(mult = 0.02)
    ) +
    ggplot2::scale_y_continuous(
      labels = ~ scales::number(.x, decimal.mark = ",")
    ) +
    ggplot2::labs(
      x       = NULL,
      y       = "Variação mensal (%)",
      title   = "Sazonalidade do IPCA",
      caption = "Fonte: BCB (série 433)"
    ) +
    .tema_base() +
    ggplot2::theme(legend.position = "right")
}


# grafico_contribuicoes --------------------------------------------------------

#' Barras horizontais: contribuição dos grupos ao IPCA no mês mais recente
#'
#' Ordena os grupos pela contribuição (maior no topo), colore positivos em
#' azul (#282f6b) e negativos em âmbar (#d97706), e anota cada barra com
#' o valor em p.p.
#'
#' @param df Tibble com colunas `grupo`, `variacao` e `peso` (e opcionalmente
#'   `contribuicao` pré-calculada), conforme `$mes_atual` retornado por
#'   [preparar_contribuicoes()].
#' @return Objeto ggplot.
grafico_contribuicoes <- function(df) {
  dados <- df |>
    dplyr::mutate(
      contribuicao = variacao * peso / 100,
      grupo        = forcats::fct_reorder(grupo, contribuicao),
      cor          = dplyr::if_else(contribuicao >= 0, "#282f6b", "#d97706"),
      hjust_txt    = dplyr::if_else(contribuicao >= 0, -0.12, 1.12)
    )

  x_lim_max <- max(dados$contribuicao, na.rm = TRUE) * 1.30
  x_lim_min <- min(0, min(dados$contribuicao, na.rm = TRUE) * 1.30)

  ggplot2::ggplot(dados, ggplot2::aes(x = contribuicao, y = grupo)) +
    ggplot2::geom_col(ggplot2::aes(fill = cor), width = 0.65) +
    ggplot2::geom_text(
      ggplot2::aes(
        label = scales::number(
          contribuicao,
          accuracy     = 0.01,
          decimal.mark = ",",
          suffix       = " p.p."
        ),
        hjust = hjust_txt
      ),
      size = 3.4
    ) +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_x_continuous(
      limits = c(x_lim_min, x_lim_max),
      expand = ggplot2::expansion(mult = 0)
    ) +
    ggplot2::labs(
      x       = "Contribuição (p.p.)",
      y       = NULL,
      title   = "Contribuição dos grupos ao IPCA",
      caption = "Fonte: IBGE/SIDRA (tabela 7060)"
    ) +
    .tema_base()
}


# salvar_grafico ---------------------------------------------------------------

#' Salva um gráfico ggplot em output/ com resolução padrão para relatório HTML
#'
#' Cria o diretório output/ se necessário e exporta o arquivo PNG.
#'
#' @param plot Objeto ggplot retornado por qualquer `grafico_*()`.
#' @param nome Nome do arquivo sem extensão (ex.: `"ipca_mensal"`).
#' @param largura Largura em polegadas (padrão: 10).
#' @param altura Altura em polegadas (padrão: 5.5).
#' @param dpi Resolução em pontos por polegada (padrão: 150).
#' @return Caminho do arquivo salvo, invisível.
salvar_grafico <- function(plot, nome, largura = 10, altura = 5.5, dpi = 150) {
  if (!dir.exists("output")) dir.create("output")
  caminho <- file.path("output", paste0(nome, ".png"))
  ggplot2::ggsave(caminho, plot = plot, width = largura, height = altura,
                  dpi = dpi, bg = "white")
  invisible(caminho)
}
