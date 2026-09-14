# Funções de visualização do painel IPCA

library(ggplot2)
library(dplyr)
library(scales)
library(lubridate)

# ── Constantes de estilo ───────────────────────────────────────────

.cor_primaria   <- "#282f6b"
.cor_secundaria <- "#d97706"
.cor_acento     <- "#059669"
.cor_cinza      <- "#6b7280"

.meses_abr <- c(
  "jan", "fev", "mar", "abr", "mai", "jun",
  "jul", "ago", "set", "out", "nov", "dez"
)

#' Rótulo "mmm/aa" em português, sem depender do locale do sistema
#'
#' `date_labels = "%b"` devolve "Oct"/"Feb" quando o runner do CI roda em
#' locale C ou en_US — e o gráfico de um relatório em português sai com meses
#' em inglês. Esta função elimina a dependência.
rotulo_mes <- function(datas) {
  paste0(
    .meses_abr[lubridate::month(datas)], "/",
    substr(format(datas, "%Y"), 3, 4)
  )
}

.tema_ipca <- function() {
  theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor  = element_blank(),
      plot.title        = element_text(face = "bold", color = .cor_primaria),
      plot.subtitle     = element_text(color = .cor_cinza, size = 9),
      axis.title        = element_text(color = .cor_cinza, size = 9),
      legend.title      = element_blank(),
      legend.position   = "bottom"
    )
}

# ── Funções de gráfico ─────────────────────────────────────────────

#' Gráfico de barras do IPCA mensal (últimos 24 meses)
#'
#' Barras positivas em azul primário, negativas em âmbar. Eixo y truncado
#' via `coord_cartesian` para ampliar o contraste visual entre barras.
#' Cada barra recebe rótulo numérico com duas casas decimais.
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm` (variação % mensal).
#' @return Objeto ggplot.
grafico_ipca_mensal <- function(df) {
  df_plot <- df |>
    dplyr::arrange(data) |>
    dplyr::slice_tail(n = 24)

  y_min  <- min(df_plot$ipca_mm, na.rm = TRUE)
  y_max  <- max(df_plot$ipca_mm, na.rm = TRUE)
  margem <- (y_max - y_min) * 0.28

  ggplot(df_plot, aes(x = data, y = ipca_mm)) +
    geom_col(
      aes(fill = ipca_mm >= 0),
      width = 25
    ) +
    geom_text(
      aes(
        label = format(round(ipca_mm, 2), nsmall = 2),
        vjust = ifelse(ipca_mm >= 0, -0.4, 1.4)
      ),
      size  = 2.8,
      color = .cor_cinza
    ) +
    scale_fill_manual(
      values = c("TRUE" = .cor_primaria, "FALSE" = .cor_secundaria),
      guide  = "none"
    ) +
    scale_x_date(labels = rotulo_mes, date_breaks = "2 months") +
    scale_y_continuous(
      labels = scales::number_format(accuracy = 0.01)
    ) +
    coord_cartesian(ylim = c(y_min - margem, y_max + margem)) +
    labs(
      title    = "IPCA — variação mensal",
      subtitle = "Últimos 24 meses (%)",
      x        = NULL,
      y        = "%"
    ) +
    .tema_ipca()
}


#' Gráfico de linha do IPCA acumulado em 12 meses com banda da meta
#'
#' Exibe a série de acumulado 12 meses, a meta anual variável (série 13521)
#' convertida para frequência mensal e a banda meta ± 1,5 p.p. O último valor
#' disponível é anotado em caixa no canto superior direito do gráfico.
#'
#' @param df      Tibble com colunas `data`, `ipca_mm` e `acum_12m`
#'                (saída de `calcular_acumulado_12m()`).
#' @param df_meta Tibble com colunas `data` e `meta_inflacao`
#'                (saída de `preparar_meta_mensal()`).
#' @return Objeto ggplot.
grafico_ipca_12m <- function(df, df_meta) {
  df_plot <- df |>
    dplyr::left_join(
      dplyr::select(df_meta, data, meta_inflacao),
      by = "data"
    ) |>
    dplyr::filter(!is.na(acum_12m), !is.na(meta_inflacao))

  ultimo <- dplyr::slice_tail(df_plot, n = 1)
  rotulo <- sprintf("%.2f%%", ultimo$acum_12m)

  ggplot(df_plot, aes(x = data)) +
    geom_ribbon(
      aes(ymin = meta_inflacao - 1.5, ymax = meta_inflacao + 1.5),
      fill  = .cor_acento,
      alpha = 0.15
    ) +
    geom_line(
      aes(y = meta_inflacao),
      color     = .cor_acento,
      linewidth = 0.7,
      linetype  = "dashed"
    ) +
    geom_line(
      aes(y = acum_12m),
      color     = .cor_primaria,
      linewidth = 1
    ) +
    annotate(
      geom     = "label",
      x        = max(df_plot$data),
      y        = Inf,
      label    = rotulo,
      hjust    = 1.05,
      vjust    = 1.5,
      fill     = .cor_primaria,
      color    = "white",
      size     = 3.5,
      fontface = "bold",
      label.padding = grid::unit(0.3, "lines"),
      label.r       = grid::unit(0.15, "lines")
    ) +
    scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    scale_y_continuous(
      labels = scales::number_format(accuracy = 0.1, suffix = "%")
    ) +
    labs(
      title    = "IPCA acumulado em 12 meses",
      subtitle = "Meta (——) e banda ±1,5 p.p. em destaque",
      x        = NULL,
      y        = "%"
    ) +
    .tema_ipca()
}


#' Gráfico sazonal — sobreposição de anos (jan–dez)
#'
#' Uma linha por ano com cor distinta. O ano mais recente recebe a cor primária
#' e traço mais espesso; os demais anos recebem gradiente de azul claro a cinza.
#' A legenda exibe todos os anos em uma única linha.
#'
#' @param df_saz Tibble com colunas `mes` (int 1–12), `ano` (fator ordenado),
#'               `ipca_mm` e `destaque` (logical), conforme retornado por
#'               `preparar_sazonal()`.
#' @return Objeto ggplot.
grafico_sazonal <- function(df_saz) {
  anos_niveis  <- levels(df_saz$ano)
  n_anos       <- length(anos_niveis)
  ano_dest_chr <- as.character(df_saz$ano[which(df_saz$destaque)[1]])

  idx_dest   <- which(anos_niveis == ano_dest_chr)
  idx_outros <- setdiff(seq_len(n_anos), idx_dest)

  paleta                <- setNames(character(n_anos), anos_niveis)
  paleta[idx_outros]    <- colorRampPalette(c("#c8ceea", .cor_cinza))(length(idx_outros))
  paleta[idx_dest]      <- .cor_primaria

  lw_legenda            <- rep(0.45, n_anos)
  lw_legenda[idx_dest]  <- 1.3

  meses_abr <- c("jan","fev","mar","abr","mai","jun",
                 "jul","ago","set","out","nov","dez")

  ggplot(df_saz, aes(x = mes, y = ipca_mm, group = ano, color = ano)) +
    geom_line(
      data      = dplyr::filter(df_saz, !destaque),
      linewidth = 0.45,
      alpha     = 0.85
    ) +
    geom_line(
      data      = dplyr::filter(df_saz, destaque),
      linewidth = 1.3
    ) +
    scale_color_manual(values = paleta) +
    scale_x_continuous(breaks = 1:12, labels = meses_abr) +
    guides(
      color = guide_legend(
        nrow         = 1,
        override.aes = list(linewidth = lw_legenda)
      )
    ) +
    labs(
      title    = "IPCA mensal — padrão sazonal",
      subtitle = "Variação % por mês do ano",
      x        = NULL,
      y        = "%"
    ) +
    .tema_ipca()
}


#' Gráfico de barras horizontais das contribuições dos grupos ao IPCA
#'
#' Grupos ordenados pela contribuição (maior no topo). Barras positivas em
#' azul primário, negativas em âmbar. Rótulos indicam a contribuição em p.p.
#' com sinal explícito.
#'
#' @param df Tibble com colunas `grupo` (chr), `variacao`, `peso` e
#'           `contribuicao` — tipicamente `preparar_contribuicoes(...)$mes_atual`.
#' @return Objeto ggplot.
grafico_contribuicoes <- function(df) {
  df_plot <- df |>
    dplyr::mutate(grupo = reorder(grupo, contribuicao))

  x_lim <- max(abs(df_plot$contribuicao), na.rm = TRUE)

  ggplot(df_plot, aes(x = contribuicao, y = grupo)) +
    geom_col(
      aes(fill = contribuicao >= 0),
      width = 0.65
    ) +
    geom_text(
      aes(
        label = sprintf("%+.2f p.p.", contribuicao),
        hjust = ifelse(contribuicao >= 0, -0.1, 1.1)
      ),
      size  = 3,
      color = .cor_cinza
    ) +
    geom_vline(xintercept = 0, color = .cor_cinza, linewidth = 0.35) +
    scale_fill_manual(
      values = c("TRUE" = .cor_primaria, "FALSE" = .cor_secundaria),
      guide  = "none"
    ) +
    scale_x_continuous(
      expand = expansion(mult = c(0.18, 0.22)),
      labels = scales::number_format(accuracy = 0.01, suffix = " p.p.")
    ) +
    labs(
      title    = "Contribuição dos grupos ao IPCA",
      subtitle = "Mês de referência mais recente",
      x        = "p.p.",
      y        = NULL
    ) +
    .tema_ipca() +
    theme(panel.grid.major.y = element_blank())
}


#' Salva uma lista nomeada de gráficos como PNG em um diretório
#'
#' Cria o diretório de destino se ainda não existir.
#' Os nomes da lista tornam-se nomes de arquivo (sem extensão).
#'
#' @param graficos Lista nomeada de objetos ggplot.
#' @param path     Diretório de destino. Padrão: `"output/"`.
#' @param width    Largura em polegadas. Padrão: 10.
#' @param height   Altura em polegadas. Padrão: 5.5.
#' @param dpi      Resolução. Padrão: 150.
#' @return Invisível: a lista `graficos` recebida.
salvar_graficos <- function(graficos, path = "output/",
                            width = 10, height = 5.5, dpi = 150) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  for (nome in names(graficos)) {
    ggplot2::ggsave(
      filename = file.path(path, paste0(nome, ".png")),
      plot     = graficos[[nome]],
      width    = width,
      height   = height,
      dpi      = dpi
    )
  }
  invisible(graficos)
}


# ══════════════════════════════════════════════════════════════════════════════
# Interatividade opcional
#
# O relatório anterior embutia PNG estático: sem tooltip, sem valor exato, sem
# zoom. Aqui os gráficos ganham camada interativa quando `ggiraph` está
# instalado, e degradam para a figura estática quando não está — o render nunca
# depende do pacote extra.
# ══════════════════════════════════════════════════════════════════════════════

tem_ggiraph <- function() requireNamespace("ggiraph", quietly = TRUE)

#' Adiciona pontos de captura invisíveis com tooltip
#'
#' Alvo de hover maior que a marca, para o cursor não precisar acertar a linha.
#'
#' @param mapeamento `aes()` com ao menos `tooltip`; `data_id` é opcional.
#' @return Camada ggplot, ou NULL quando ggiraph não está disponível.
camada_interativa <- function(mapeamento, tamanho = 3) {
  if (!tem_ggiraph()) {
    return(NULL)
  }
  ggiraph::geom_point_interactive(
    mapping = mapeamento, size = tamanho, alpha = 0.01, show.legend = FALSE
  )
}

#' Renderiza como widget interativo, ou devolve o ggplot intacto
#'
#' @param p Objeto ggplot.
#' @param altura,largura Dimensões do SVG, em polegadas.
#' @return `girafe` quando ggiraph existe; o próprio `p` caso contrário.
renderizar <- function(p, altura = 4.2, largura = 9) {
  if (!tem_ggiraph()) {
    return(p)
  }
  ggiraph::girafe(
    ggobj = p, width_svg = largura, height_svg = altura,
    options = list(
      ggiraph::opts_hover(css = "stroke-width:2.5;"),
      ggiraph::opts_hover_inv(css = "opacity:0.35;"),
      ggiraph::opts_tooltip(
        css = paste(
          "background:#ffffff;border:1px solid #d9d9e3;border-radius:6px;",
          "padding:6px 9px;font-family:sans-serif;font-size:12px;",
          "color:#1a1a1a;box-shadow:0 4px 14px rgba(0,0,0,.12);"
        ),
        opacity = 1
      ),
      ggiraph::opts_toolbar(saveaspng = TRUE, position = "topright")
    )
  )
}

#' Formata número no padrão brasileiro para uso em tooltip
fmt_br <- function(x, casas = 2) {
  formatC(x, format = "f", digits = casas, decimal.mark = ",", big.mark = ".")
}


# ══════════════════════════════════════════════════════════════════════════════
# Gráficos novos
# ══════════════════════════════════════════════════════════════════════════════

#' Ritmo da inflação: acumulado em 12 meses contra trimestre anualizado
#'
#' O acumulado em doze meses é a medida de referência, mas carrega inércia:
#' continua subindo meses depois de o ritmo corrente já ter virado. O trimestre
#' anualizado mostra a inflação que está sendo gerada agora. Quando as duas
#' linhas se cruzam, o acumulado tende a seguir o trimestre nos meses seguintes.
#'
#' Sem ajuste sazonal — o subtítulo diz isso, e o leitor deve comparar com o
#' mesmo trimestre de anos anteriores antes de concluir por inflexão.
#'
#' @param df Tibble com `data`, `acum_12m` e `anualizado_3m`.
#' @param meta Centro da meta contínua, para a linha de referência.
#' @param banda Tolerância em p.p.
#' @param anos Quantos anos exibir. Padrão: 6.
#' @return Objeto ggplot.
grafico_ritmo <- function(df, meta = 3, banda = 1.5, anos = 6) {
  corte <- max(df$data, na.rm = TRUE) - anos * 365
  df_plot <- df |>
    dplyr::filter(data >= corte, !is.na(acum_12m) | !is.na(anualizado_3m)) |>
    dplyr::select(data, acum_12m, anualizado_3m) |>
    tidyr::pivot_longer(-data, names_to = "serie", values_to = "valor") |>
    dplyr::filter(!is.na(valor)) |>
    dplyr::mutate(
      serie = factor(
        serie,
        levels = c("acum_12m", "anualizado_3m"),
        labels = c("Acumulado 12 meses", "Trimestre anualizado")
      ),
      dica = paste0(rotulo_mes(data), " — ", serie, ": ", fmt_br(valor), "%")
    )

  ggplot(df_plot, aes(x = data, y = valor, color = serie, group = serie)) +
    annotate(
      "rect",
      xmin = min(df_plot$data), xmax = max(df_plot$data),
      ymin = meta - banda, ymax = meta + banda,
      fill = .cor_acento, alpha = 0.10
    ) +
    geom_hline(yintercept = meta, color = .cor_acento, linewidth = 0.6, linetype = "dashed") +
    geom_line(linewidth = 1) +
    camada_interativa(aes(tooltip = dica, data_id = as.character(data))) +
    scale_color_manual(values = c(
      "Acumulado 12 meses" = .cor_primaria,
      "Trimestre anualizado" = .cor_secundaria
    )) +
    scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    scale_y_continuous(labels = scales::number_format(accuracy = 0.1, suffix = "%")) +
    labs(
      title = "Ritmo da inflação",
      subtitle = paste0(
        "Acumulado em 12 meses e trimestre anualizado (sem ajuste sazonal). ",
        "Faixa: meta contínua de ", fmt_br(meta, 2), "% ± ", fmt_br(banda, 1), " p.p."
      ),
      x = NULL, y = "%"
    ) +
    .tema_ipca()
}


#' Índice cheio contra núcleo por médias aparadas
#'
#' O índice cheio responde a choque concentrado — energia, combustível,
#' alimento in natura. O núcleo apara as caudas e mostra a tendência que
#' sobrevive ao choque. Distância grande e persistente entre as duas linhas
#' indica que a leitura corrente é de oferta, não de demanda.
#'
#' @param df Tibble com `data`, `ipca_mm` e `nucleo_aparado`.
#' @param meses Quantos meses exibir. Padrão: 36.
#' @return Objeto ggplot.
grafico_nucleo <- function(df, meses = 36) {
  df_plot <- df |>
    dplyr::filter(!is.na(nucleo_aparado)) |>
    dplyr::arrange(data) |>
    dplyr::slice_tail(n = meses) |>
    dplyr::select(data, ipca_mm, nucleo_aparado) |>
    tidyr::pivot_longer(-data, names_to = "serie", values_to = "valor") |>
    dplyr::filter(!is.na(valor)) |>
    dplyr::mutate(
      serie = factor(
        serie,
        levels = c("ipca_mm", "nucleo_aparado"),
        labels = c("IPCA cheio", "Núcleo — média aparada entre grupos")
      ),
      dica = paste0(rotulo_mes(data), " — ", serie, ": ", fmt_br(valor), "%")
    )

  ggplot(df_plot, aes(x = data, y = valor, color = serie, group = serie)) +
    geom_hline(yintercept = 0, color = .cor_cinza, linewidth = 0.35) +
    geom_line(linewidth = 1) +
    camada_interativa(aes(tooltip = dica, data_id = as.character(data))) +
    scale_color_manual(values = c(
      "IPCA cheio" = .cor_primaria,
      "Núcleo — média aparada entre grupos" = .cor_secundaria
    )) +
    scale_x_date(labels = rotulo_mes, date_breaks = "4 months") +
    scale_y_continuous(labels = scales::number_format(accuracy = 0.01, suffix = "%")) +
    labs(
      title = "IPCA cheio e núcleo",
      subtitle = paste0(
        "Variação mensal. O núcleo apara 20% do peso em cada cauda da ",
        "distribuição dos nove grupos — medida derivada, não o IPCA-MS do BCB."
      ),
      x = NULL, y = "%"
    ) +
    .tema_ipca()
}


#' Difusão entre os grupos, mês a mês
#'
#' Responde ao que o índice cheio não responde: a inflação do mês veio de poucos
#' grupos ou de muitos? A linha tracejada é a média histórica da própria série —
#' difusão acima dela indica pressão mais espalhada que o usual.
#'
#' @param df Tibble com `data` e `difusao`.
#' @param meses Quantos meses exibir. Padrão: 36.
#' @return Objeto ggplot.
grafico_difusao <- function(df, meses = 36) {
  df_plot <- df |>
    dplyr::filter(!is.na(difusao)) |>
    dplyr::arrange(data) |>
    dplyr::slice_tail(n = meses) |>
    dplyr::mutate(
      dica = paste0(rotulo_mes(data), " — difusão: ", fmt_br(difusao, 1), "%")
    )

  media <- mean(df_plot$difusao, na.rm = TRUE)

  ggplot(df_plot, aes(x = data, y = difusao)) +
    geom_col(aes(fill = difusao >= media), width = 25) +
    camada_interativa(aes(tooltip = dica, data_id = as.character(data))) +
    geom_hline(yintercept = media, color = .cor_cinza, linewidth = 0.6, linetype = "dashed") +
    annotate(
      "text",
      x = min(df_plot$data), y = 97, hjust = 0, vjust = 1,
      label = paste0("média do período: ", fmt_br(media, 1), "%"),
      size = 2.9, color = .cor_cinza
    ) +
    scale_fill_manual(
      values = c("TRUE" = .cor_primaria, "FALSE" = .cor_cinza), guide = "none"
    ) +
    scale_x_date(labels = rotulo_mes, date_breaks = "4 months") +
    scale_y_continuous(
      limits = c(0, 100), labels = scales::number_format(accuracy = 1, suffix = "%")
    ) +
    labs(
      title = "Difusão da inflação",
      subtitle = "Proporção dos nove grupos de despesa com variação positiva no mês",
      x = NULL, y = "% dos grupos"
    ) +
    .tema_ipca()
}
