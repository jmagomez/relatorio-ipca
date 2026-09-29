# Gráficos do Boletim Macro Semanal
#
# Por que este arquivo existe
# ---------------------------
# O boletim semanal publicava quatro números numa tabela e nenhum gráfico,
# enquanto `output/dados/` guardava 560 meses de IPCA (desde 1980), 283 de
# IBC-Br (desde 2003) e dois anos de Selic e câmbio diários. A série inteira
# era coletada, versionada e nunca desenhada.
#
# As funções moram aqui, e não no `boletim.qmd`, por um motivo estrutural: o
# `.qmd` é reescrito do zero toda segunda pelo agente redator. Gráfico escrito
# lá dentro dura uma semana. É a mesma razão pela qual o `_quarto.yml` carrega
# a proteção do cifrão — CLAUDE.MD chama essa linha de "a única proteção que
# sobrevive à regeneração semanal".
#
# Depende de `graficos.R` (cores, tema e `rotulo_mes()`), carregado aqui pelo
# caminho do próprio script para que este arquivo funcione tanto dentro do
# render quanto chamado sozinho por `Rscript`.

local({
  if (exists("rotulo_mes", inherits = TRUE)) {
    return(invisible(NULL))
  }
  # Mesma resolução de três vias de `corpo_email.R`: `--file=` cobre o
  # Rscript, `ofile` cobre o source, e a busca por `_quarto.yml` cobre o
  # runner dos testes, que roda com o diretório de trabalho em `tests/`.
  por_source <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NA_character_)
  candidatos <- c(
    if (!is.na(por_source)) por_source,
    {
      arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
      if (length(arg) > 0) dirname(normalizePath(sub("^--file=", "", arg[1]), mustWork = FALSE))
    },
    {
      caminho <- normalizePath(".", mustWork = FALSE)
      while (!file.exists(file.path(caminho, "_quarto.yml")) && dirname(caminho) != caminho) {
        caminho <- dirname(caminho)
      }
      file.path(caminho, "R")
    }
  )
  for (dir_script in candidatos) {
    alvo <- file.path(dir_script, "graficos.R")
    if (file.exists(alvo)) {
      source(alvo)
      return(invisible(NULL))
    }
  }
  stop("graficos.R nao encontrado: graficos_boletim.R depende dele.", call. = FALSE)
})

suppressMessages({
  library(ggplot2)
  library(dplyr)
})


# ── Regime de metas ─────────────────────────────────────────────
#
# A meta CONTÍNUA vigora desde janeiro de 2025: centro de 3,00% com tolerância
# de ±1,5 p.p., avaliada mês a mês sobre o IPCA acumulado em doze meses, e o
# descumprimento se caracteriza com seis meses consecutivos fora.
#
# Antes de 2025 a meta era de ano-calendário e o centro era OUTRO: 3,25% em
# 2023, 3,50% em 2022, 3,75% em 2021. Por isso a faixa só é desenhada a partir
# de `INICIO_META_CONTINUA`. Sombrear 3,00% ± 1,5 sobre o período anterior
# afirmaria que o IPCA de 2022 era avaliado contra uma meta que ainda não
# existia — o tipo de anacronismo que o leitor deste boletim percebe.

META_CENTRO <- 3.00
META_BANDA <- 1.50
INICIO_META_CONTINUA <- as.Date("2025-01-01")

#: Meses consecutivos fora da banda que caracterizam descumprimento e obrigam
#: o presidente do BC a enviar carta aberta ao Ministro da Fazenda.
MESES_PARA_DESCUMPRIMENTO <- 6L


#' Situação corrente do IPCA acumulado em 12 meses contra a meta contínua
#'
#' O boletim reportava o acumulado em doze meses como número solto — "a
#' variação alcança 4,22%" — sem dizer onde esse número cai dentro da banda
#' que define o regime. Para quem acompanha política monetária, a distância
#' até o teto e a contagem de meses consecutivos fora são a leitura; o nível
#' isolado não é.
#'
#' `avaliar_meta_continua()` já existia em `tratamento.R`, testada, e era usada
#' apenas pelo relatório mensal.
#'
#' @param df_meta Saída de `avaliar_meta_continua()`.
#' @return Lista com os campos que o texto do boletim precisa, ou `NULL` se
#'   não houver observação utilizável.
situacao_meta <- function(df_meta) {
  if (is.null(df_meta) || nrow(df_meta) == 0) {
    return(NULL)
  }
  ultima <- df_meta[nrow(df_meta), ]
  piso <- META_CENTRO - META_BANDA
  teto <- META_CENTRO + META_BANDA

  # Quantos meses consecutivos ATÉ AQUI, olhando para trás a partir do fim.
  # Difere de `meses_consecutivos_fora` quando a série termina dentro da
  # banda: ali o contador é zero, e o que interessa passa a ser há quanto
  # tempo está dentro.
  dentro <- !df_meta$fora_da_banda
  n <- nrow(df_meta)
  corrida_dentro <- 0L
  for (i in rev(seq_len(n))) {
    if (isTRUE(dentro[i])) corrida_dentro <- corrida_dentro + 1L else break
  }

  # A contagem que vale é a do REGIME, reiniciada em jan/2025.
  #
  # `avaliar_meta_continua()` roda o contador sobre a série inteira, que
  # começa em dez/1980: aplicada a ela, a banda de hoje acha uma corrida de
  # 208 meses terminada em mar/1998. A corrida recente, de 13 meses, começou
  # em out/2024, quando a meta ainda era de ano-calendário e o centro era
  # outro. Nenhum desses meses era avaliado contra 3,00% ± 1,5; contá-los
  # como descumprimento do regime contínuo é aplicar a regra de 2025 a um
  # período que ela não governava. Sob o regime, a maior corrida tem 10 meses
  # (jan/2025 a out/2025) — ainda bem acima dos seis que caracterizam
  # descumprimento, mas é este o número correto.
  sob_regime <- df_meta[df_meta$data >= INICIO_META_CONTINUA, , drop = FALSE]
  maior_fora_regime <- 0L
  if (nrow(sob_regime) > 0) {
    corrente <- 0L
    for (i in seq_len(nrow(sob_regime))) {
      corrente <- if (isTRUE(sob_regime$fora_da_banda[i])) corrente + 1L else 0L
      maior_fora_regime <- max(maior_fora_regime, corrente)
    }
  }

  list(
    data = ultima$data,
    acum_12m = ultima$acum_12m,
    desvio = ultima$desvio,
    piso = piso,
    teto = teto,
    fora = isTRUE(ultima$fora_da_banda),
    folga_ate_o_teto = teto - ultima$acum_12m,
    folga_ate_o_piso = ultima$acum_12m - piso,
    meses_consecutivos_fora = ultima$meses_consecutivos_fora,
    meses_consecutivos_dentro = corrida_dentro,
    limite_descumprimento = MESES_PARA_DESCUMPRIMENTO,
    # Contexto que o número corrente sozinho não dá, todo restrito ao regime.
    maior_sequencia_fora = maior_fora_regime,
    meses_fora_sob_regime = sum(sob_regime$fora_da_banda, na.rm = TRUE),
    total_meses_sob_regime = nrow(sob_regime)
  )
}


#' A situação da meta escrita por extenso, uma vez só
#'
#' Havia duas redações do mesmo parágrafo: uma em `corpo_email.R`, montada por
#' este código, e outra escrita à mão pelo agente redator dentro do
#' `boletim.qmd`. Com os mesmos dados, o e-mail dizia "no 2º mês seguido
#' dentro" enquanto o boletim publicava "Há 0 mês(es) consecutivo(s) fora da
#' banda" — redação que só aparece justamente quando a notícia é boa.
#'
#' Reunir as duas aqui resolve o caso zero de uma vez e impede que voltem a
#' divergir: o `.qmd` é reescrito toda semana, este arquivo não.
#'
#' @param s Saída de `situacao_meta()`.
#' @param enfase Par (abre, fecha) para destacar os números. O padrão é
#'   Markdown, que serve ao `.qmd`; `corpo_email.R` passa `<strong>`.
#' @return Parágrafo único, ou `NULL` quando não há situação a relatar.
frase_meta <- function(s, enfase = c("**", "**")) {
  if (is.null(s)) {
    return(NULL)
  }
  abre <- enfase[1]
  fecha <- enfase[2]
  destaque <- function(x) paste0(abre, x, fecha)

  banda <- paste0("banda de ", fmt_br(s$piso, 2), "% a ", fmt_br(s$teto, 2), "%")

  if (s$fora) {
    posicao <- if (s$acum_12m > s$teto) "acima do teto" else "abaixo do piso"
    corpo <- paste0(
      "está ", destaque(posicao), " da ", banda, ", pelo ",
      s$meses_consecutivos_fora, "º mês consecutivo. ",
      "São ", s$limite_descumprimento,
      " meses seguidos fora que caracterizam descumprimento e obrigam o ",
      "presidente do BC a enviar carta aberta ao Ministro da Fazenda."
    )
  } else {
    # O trecho da sequência some quando ela é zero. Dizer "no 0º mês seguido
    # dentro" é pior do que não dizer nada.
    corpo <- paste0(
      "está ", destaque("dentro"), " da ", banda,
      ", a ", fmt_br(s$folga_ate_o_teto, 2), " p.p. do teto",
      if (s$meses_consecutivos_dentro > 0) {
        paste0(" e no ", s$meses_consecutivos_dentro, "º mês seguido dentro")
      } else {
        ""
      },
      "."
    )
  }

  contexto <- paste0(
    " Desde a entrada do regime contínuo, em jan/2025, foram ",
    s$meses_fora_sob_regime, " dos ", s$total_meses_sob_regime,
    " meses fora da banda, com sequência máxima de ",
    s$maior_sequencia_fora, " meses consecutivos."
  )

  paste0(
    "IPCA acumulado em 12 meses: ", destaque(paste0(fmt_br(s$acum_12m, 2), "%")),
    " (", format(as.Date(s$data), "%m/%Y"), "). O índice ", corpo, contexto
  )
}


#' IPCA acumulado em 12 meses contra a banda da meta contínua
#'
#' O gráfico que faltava. A linha é o acumulado em doze meses; a faixa é a
#' banda de tolerância, desenhada **apenas a partir de janeiro de 2025**,
#' quando o regime contínuo entrou em vigor. Os meses fora da banda recebem
#' marcador, porque é a contagem deles — seis consecutivos — que caracteriza
#' descumprimento.
#'
#' @param df_meta Saída de `avaliar_meta_continua()`.
#' @param anos Janela em anos. Padrão: 6.
#' @return Objeto ggplot, ou `NULL` se não houver dados suficientes.
grafico_meta_continua <- function(df_meta, anos = 6) {
  if (is.null(df_meta) || nrow(df_meta) < 2) {
    return(NULL)
  }
  fim <- max(df_meta$data, na.rm = TRUE)
  df_plot <- df_meta |>
    dplyr::filter(data >= fim - anos * 365, !is.na(acum_12m))
  if (nrow(df_plot) < 2) {
    return(NULL)
  }

  inicio_faixa <- max(INICIO_META_CONTINUA, min(df_plot$data))

  # Marcar como "fora da banda" um mês anterior a jan/2025 seria julgar o
  # passado pela régua do presente: antes do regime contínuo a meta era de
  # ano-calendário e o centro era outro (3,25% em 2023, 3,50% em 2022). A
  # faixa já é desenhada só a partir do regime; os pontos seguem a mesma
  # regra, ou o gráfico diria que 2021 descumpriu uma meta inexistente.
  fora <- dplyr::filter(df_plot, fora_da_banda, data >= INICIO_META_CONTINUA)

  p <- ggplot(df_plot, aes(x = data, y = acum_12m)) +
    annotate(
      "rect",
      xmin = inicio_faixa, xmax = fim,
      ymin = META_CENTRO - META_BANDA, ymax = META_CENTRO + META_BANDA,
      fill = .cor_acento, alpha = 0.10
    ) +
    annotate(
      "segment",
      x = inicio_faixa, xend = fim,
      y = META_CENTRO, yend = META_CENTRO,
      color = .cor_acento, linewidth = 0.6, linetype = "dashed"
    ) +
    geom_line(color = .cor_primaria, linewidth = 1)

  if (nrow(fora) > 0) {
    p <- p + geom_point(
      data = fora, aes(x = data, y = acum_12m),
      color = .cor_secundaria, size = 1.6
    )
  }

  # A marca de início do regime só é informativa quando a janela alcança o
  # período anterior a ele.
  if (min(df_plot$data) < INICIO_META_CONTINUA) {
    p <- p +
      annotate(
        "segment",
        x = INICIO_META_CONTINUA, xend = INICIO_META_CONTINUA,
        y = -Inf, yend = Inf,
        color = .cor_cinza, linewidth = 0.4, linetype = "dotted"
      ) +
      annotate(
        "text",
        x = INICIO_META_CONTINUA, y = max(df_plot$acum_12m, na.rm = TRUE),
        label = " meta contínua",
        hjust = 0, vjust = 1, size = 2.9, color = .cor_cinza
      )
  }

  p +
    scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    scale_y_continuous(labels = scales::number_format(accuracy = 0.1, suffix = "%")) +
    labs(
      title = "IPCA em 12 meses e a banda da meta contínua",
      subtitle = paste0(
        "Faixa: ", fmt_br(META_CENTRO, 2), "% ± ", fmt_br(META_BANDA, 1),
        " p.p., válida desde jan/2025. Pontos marcam os meses fora da banda; ",
        MESES_PARA_DESCUMPRIMENTO, " consecutivos caracterizam descumprimento."
      ),
      x = NULL, y = NULL
    ) +
    .tema_ipca()
}


#' Trajetória da meta Selic, em degraus
#'
#' `geom_step()`, não `geom_line()`. A meta Selic só muda por decisão do Copom
#' e fica constante entre reuniões; ligar as observações por reta inclinada
#' desenharia um ajuste gradual que não existe e sugeriria, na leitura visual,
#' taxas intermediárias que nunca vigoraram.
#'
#' @param df Tibble com `data` e `valor` (% a.a.).
#' @param anos Janela em anos. Padrão: 2.
#' @return Objeto ggplot, ou `NULL` se não houver dados suficientes.
grafico_selic <- function(df, anos = 2) {
  if (is.null(df) || nrow(df) < 2) {
    return(NULL)
  }
  fim <- max(df$data, na.rm = TRUE)
  df_plot <- dplyr::filter(df, data >= fim - anos * 365, !is.na(valor))
  if (nrow(df_plot) < 2) {
    return(NULL)
  }

  ggplot(df_plot, aes(x = data, y = valor)) +
    geom_step(color = .cor_primaria, linewidth = 0.9) +
    scale_x_date(labels = rotulo_mes, date_breaks = "4 months") +
    scale_y_continuous(labels = scales::number_format(accuracy = 0.25, suffix = "%")) +
    labs(
      title = "Meta da taxa Selic",
      subtitle = paste0(
        "Em % ao ano. Degraus, não reta: a meta é constante entre reuniões ",
        "do Copom. Variações reportadas em p.p."
      ),
      x = NULL, y = NULL
    ) +
    .tema_ipca()
}


#' Câmbio R$/US$ — cotação diária de fechamento
#'
#' @param df Tibble com `data` e `valor` (R$/US$).
#' @param anos Janela em anos. Padrão: 2.
#' @return Objeto ggplot, ou `NULL` se não houver dados suficientes.
grafico_cambio <- function(df, anos = 2) {
  if (is.null(df) || nrow(df) < 2) {
    return(NULL)
  }
  fim <- max(df$data, na.rm = TRUE)
  df_plot <- dplyr::filter(df, data >= fim - anos * 365, !is.na(valor))
  if (nrow(df_plot) < 2) {
    return(NULL)
  }

  ggplot(df_plot, aes(x = data, y = valor)) +
    geom_line(color = .cor_primaria, linewidth = 0.8) +
    scale_x_date(labels = rotulo_mes, date_breaks = "4 months") +
    scale_y_continuous(labels = function(x) paste0("R$ ", fmt_br(x, 2))) +
    labs(
      title = "Câmbio R$/US$",
      subtitle = "Cotação de fechamento (venda). Alta = depreciação do Real.",
      x = NULL, y = NULL
    ) +
    .tema_ipca()
}


#' IBC-Br com ajuste sazonal — nível do índice
#'
#' Usa a série COM ajuste sazonal (SGS 24364), que é a única em que comparar
#' nível contra nível na margem tem sentido. A série original (24363) serve
#' para as variações interanuais por média de período, e não para leitura de
#' margem — é a distinção que o CLAUDE.MD deste projeto registra como erro já
#' cometido e corrigido.
#'
#' @param df Tibble com `data` e `valor` (índice, série SA).
#' @param meses Janela em meses. Padrão: 48.
#' @return Objeto ggplot, ou `NULL` se não houver dados suficientes.
grafico_ibcbr <- function(df, meses = 48) {
  if (is.null(df) || nrow(df) < 2) {
    return(NULL)
  }
  df_plot <- df |>
    dplyr::filter(!is.na(valor)) |>
    dplyr::arrange(data) |>
    dplyr::slice_tail(n = meses)
  if (nrow(df_plot) < 2) {
    return(NULL)
  }

  ggplot(df_plot, aes(x = data, y = valor)) +
    geom_line(color = .cor_primaria, linewidth = 0.9) +
    scale_x_date(labels = rotulo_mes, date_breaks = "6 months") +
    scale_y_continuous(labels = function(x) fmt_br(x, 1)) +
    labs(
      title = "IBC-Br com ajuste sazonal",
      subtitle = paste0(
        "Nível do índice, série dessazonalizada (SGS 24364) — ",
        "a única em que a comparação de margem tem sentido."
      ),
      x = NULL, y = NULL
    ) +
    .tema_ipca()
}


#' Carrega uma série de `output/dados/` sem derrubar o boletim
#'
#' A regra do projeto é falha POR SÉRIE, nunca global: uma fonte ausente vira
#' "indicador indisponível nesta semana", e não erro de render. Por isso esta
#' função devolve `NULL` em vez de parar.
#'
#' @param caminho Caminho do CSV com colunas `data` e `valor`.
#' @return Tibble com `data` (Date) e `valor` (numérico), ou `NULL`.
ler_serie_boletim <- function(caminho) {
  if (!file.exists(caminho)) {
    return(NULL)
  }
  df <- try(utils::read.csv(caminho, stringsAsFactors = FALSE), silent = TRUE)
  if (inherits(df, "try-error") || !all(c("data", "valor") %in% names(df))) {
    return(NULL)
  }
  df$data <- as.Date(df$data)
  df$valor <- suppressWarnings(as.numeric(df$valor))
  df <- df[!is.na(df$data), , drop = FALSE]
  if (nrow(df) == 0) NULL else dplyr::arrange(df, data)
}
