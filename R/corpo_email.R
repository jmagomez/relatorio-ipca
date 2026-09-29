#!/usr/bin/env Rscript
#
# Monta o CORPO do e-mail do Boletim Macro Semanal.
#
# Por que este arquivo existe
# ---------------------------
# O workflow enviava como corpo o `boletim.html` inteiro, com um rodapé
# costurado antes do `</body>`. Esse arquivo tem 1.859 KB, dos quais o
# conteúdo real — o que está dentro de `<main>` — são 5,9 KB. Os outros
# 99,7% são o tema Bootstrap do Quarto: 333 KB de CSS, 151 KB de JS e 272 KB
# de fontes embutidas em base64. O mesmo arquivo ainda ia anexado, então cada
# envio carregava cerca de 3,7 MB.
#
# O Gmail trunca o corpo de mensagens acima de ~102 KB e mostra "mensagem
# truncada" com um link para ver o resto. Um boletim de 1,86 MB cai
# confortavelmente nesse corte.
#
# Este script monta um corpo próprio, feito para cliente de e-mail:
#
#   * tabela com estilo inline, sem CSS externo, sem JS, sem fonte embutida;
#   * NENHUM `<svg>` — Gmail e Outlook removem SVG inline. Os gráficos moram
#     no `boletim.html` anexado e na versão do Connect Cloud, que abrem em
#     navegador de verdade;
#   * o HTML é escrito direto, sem passar pelo Pandoc, o que elimina de vez o
#     risco do `R$/US$` virar fórmula matemática.
#
# Uso:
#   Rscript R/corpo_email.R [data_ref] [saida.html]

suppressMessages({
  library(dplyr)
})

# Onde está a pasta R/, seja qual for a forma de entrada.
#
# São três, e cada uma quebra as outras duas:
#   * `Rscript R/corpo_email.R` do diretório raiz  -> `--file=`
#   * `source("R/corpo_email.R")` de dentro do render -> `sys.frame(1)$ofile`
#   * `source(...)` a partir de `tests/`, onde o runner roda -> nenhuma das
#     duas serve, e um fallback fixo de "R" aponta para `tests/R`, que não
#     existe. Foi assim que a primeira versão deste arquivo quebrou quatro
#     testes de uma vez.
#
# A busca por `_quarto.yml` é a mesma regra de `raiz_projeto()` e funciona de
# qualquer diretório — por isso é o último recurso, e o que sempre acerta.
.dir_script <- local({
  por_source <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NA_character_)
  if (!is.na(por_source) && nzchar(por_source) &&
    file.exists(file.path(por_source, "tratamento.R"))) {
    return(por_source)
  }

  args <- commandArgs(trailingOnly = FALSE)
  arg_file <- grep("^--file=", args, value = TRUE)
  if (length(arg_file) > 0) {
    candidato <- dirname(normalizePath(sub("^--file=", "", arg_file[1]), mustWork = FALSE))
    if (file.exists(file.path(candidato, "tratamento.R"))) {
      return(candidato)
    }
  }

  caminho <- normalizePath(".", mustWork = FALSE)
  while (!file.exists(file.path(caminho, "_quarto.yml")) && dirname(caminho) != caminho) {
    caminho <- dirname(caminho)
  }
  file.path(caminho, "R")
})

# `coleta_sgs.R` é a casa de `raiz_projeto()`, o localizador canônico do
# projeto — CLAUDE.MD proíbe caminho absoluto. Ele carrega sem o `rbcb`
# instalado: a dependência de rede só é exigida dentro das funções de coleta,
# nenhuma das quais é chamada aqui.
source(file.path(.dir_script, "coleta_sgs.R"))
source(file.path(.dir_script, "tratamento.R"))
source(file.path(.dir_script, "graficos.R"))
source(file.path(.dir_script, "graficos_boletim.R"))

URL_CONNECT <- paste0(
  "https://connect.posit.cloud/jmagomez/content/",
  "019f5da4-43ea-2bed-6bbd-90e3f7aaca72"
)

#: Limite prático do Gmail antes de truncar o corpo da mensagem.
LIMITE_GMAIL_BYTES <- 102400L


# ── Formatação ─────────────────────────────────────────────────────────

#' Escapa o que não pode ir cru para dentro do HTML
esc_html <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub('"', "&quot;", x, fixed = TRUE)
}

#' Número no padrão brasileiro, ou a mensagem-padrão de indisponibilidade
#'
#' Nunca deve sair "NA" no e-mail: todo número exibido passa por aqui.
fmt_valor <- function(x, casas = 2, prefixo = "", sufixo = "") {
  if (is.null(x) || length(x) != 1 || is.na(x)) {
    return("indisponível nesta semana")
  }
  paste0(prefixo, fmt_br(as.numeric(x), casas), sufixo)
}

#' Variação com sinal explícito — em e-mail o leitor não tem cor para se guiar
fmt_var <- function(x, casas = 2, sufixo = "%") {
  if (is.null(x) || length(x) != 1 || is.na(x)) {
    return("&mdash;")
  }
  x <- as.numeric(x)
  paste0(if (x > 0) "+" else "", fmt_br(x, casas), sufixo)
}

fmt_data_br <- function(x, dia = FALSE) {
  if (is.null(x) || length(x) != 1 || is.na(x)) {
    return("&mdash;")
  }
  format(as.Date(x), if (dia) "%d/%m/%Y" else "%m/%Y")
}


# ── Leitura do resumo ──────────────────────────────────────────────────

ler_resumo <- function(caminho) {
  if (!file.exists(caminho)) {
    return(NULL)
  }
  df <- try(utils::read.csv(caminho, stringsAsFactors = FALSE), silent = TRUE)
  if (inherits(df, "try-error") || nrow(df) == 0) NULL else df
}

#' Extrai um indicador do resumo, devolvendo NAs quando ele não consta
#'
#' Falha por série, nunca global: uma fonte fora do ar vira uma célula
#' "indisponível nesta semana" e o restante do boletim segue.
extrai_indicador <- function(df, nome) {
  vazio <- list(
    valor_atual = NA_real_, data_ref = NA_character_,
    var_mes = NA_real_, var_ano = NA_real_, var_12m = NA_real_
  )
  if (is.null(df)) {
    return(vazio)
  }
  linha <- df[df$indicador == nome, , drop = FALSE]
  if (nrow(linha) == 0) vazio else as.list(linha[1, ])
}


# ── A leitura da meta ─────────────────────────────────────────────────

#' Frase de abertura: onde o IPCA está em relação à banda
#'
#' É a informação que o boletim não dava. O acumulado em doze meses saía como
#' número solto — "a variação alcança 4,22%" — sem dizer que o teto da banda é
#' 4,50%, nem quantos meses consecutivos fora caracterizam descumprimento.
frase_meta <- function(s) {
  if (is.null(s)) {
    return(NULL)
  }
  banda <- paste0(
    "banda de ", fmt_br(s$piso, 2), "% a ", fmt_br(s$teto, 2), "%"
  )
  if (s$fora) {
    posicao <- if (s$acum_12m > s$teto) "acima do teto" else "abaixo do piso"
    corpo <- paste0(
      "está <strong>", posicao, "</strong> da ", banda, ", pelo ",
      s$meses_consecutivos_fora, "º mês consecutivo. ",
      "São ", s$limite_descumprimento,
      " meses seguidos fora que caracterizam descumprimento e obrigam o ",
      "presidente do BC a enviar carta aberta ao Ministro da Fazenda."
    )
  } else {
    corpo <- paste0(
      "está <strong>dentro</strong> da ", banda,
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
    "IPCA acumulado em 12 meses: <strong>", fmt_br(s$acum_12m, 2),
    "%</strong> (", fmt_data_br(s$data), "). O índice ", corpo, contexto
  )
}


# ── Montagem do HTML ──────────────────────────────────────────────────

.css_celula <- "padding:8px 10px;border-bottom:1px solid #e5e7eb;"
.css_num <- paste0(.css_celula, "text-align:right;font-variant-numeric:tabular-nums;")

linha_tabela <- function(rotulo, valor, var_mes, var_12m) {
  paste0(
    "<tr>",
    '<td style="', .css_celula, '">', rotulo, "</td>",
    '<td style="', .css_num, '">', valor, "</td>",
    '<td style="', .css_num, '">', var_mes, "</td>",
    '<td style="', .css_num, '">', var_12m, "</td>",
    "</tr>"
  )
}

#' Monta o corpo completo do e-mail
#'
#' @param data_ref Data de referência do boletim (texto "AAAA-MM-DD").
#' @param dir_dados Pasta com os CSVs coletados.
#' @return String com o HTML.
montar_corpo <- function(data_ref = as.character(Sys.Date()),
                         dir_dados = file.path(raiz_projeto(), "output", "dados")) {
  resumo <- ler_resumo(file.path(dir_dados, "resumo.csv"))
  ipca <- extrai_indicador(resumo, "IPCA")
  cambio <- extrai_indicador(resumo, "Cambio R$/US$")
  selic <- extrai_indicador(resumo, "Selic meta")
  ibc <- extrai_indicador(resumo, "IBC-Br")

  # A leitura da meta vem da série completa, não do resumo de quatro linhas.
  serie_ipca <- ler_serie_boletim(file.path(dir_dados, "ipca.csv"))
  situacao <- NULL
  if (!is.null(serie_ipca)) {
    df_meta <- serie_ipca |>
      dplyr::rename(ipca_mm = valor) |>
      calcular_acumulado_12m() |>
      avaliar_meta_continua(META_CENTRO, META_BANDA)
    situacao <- situacao_meta(df_meta)
  }

  abertura <- frase_meta(situacao)

  linhas <- paste0(
    linha_tabela(
      paste0("IPCA <span style=\"color:#6b7280\">(", fmt_data_br(ipca$data_ref), ")</span>"),
      fmt_valor(ipca$valor_atual, 2, sufixo = "%"),
      fmt_var(ipca$var_mes), fmt_var(ipca$var_12m)
    ),
    linha_tabela(
      paste0("C&#226;mbio R$/US$ <span style=\"color:#6b7280\">(", fmt_data_br(cambio$data_ref, TRUE), ")</span>"),
      fmt_valor(cambio$valor_atual, 2, prefixo = "R$ "),
      fmt_var(cambio$var_mes), fmt_var(cambio$var_12m)
    ),
    linha_tabela(
      paste0("Selic meta <span style=\"color:#6b7280\">(", fmt_data_br(selic$data_ref, TRUE), ")</span>"),
      fmt_valor(selic$valor_atual, 2, sufixo = "% a.a."),
      fmt_var(selic$var_mes, sufixo = " p.p."), fmt_var(selic$var_12m, sufixo = " p.p.")
    ),
    linha_tabela(
      paste0("IBC-Br <span style=\"color:#6b7280\">(", fmt_data_br(ibc$data_ref), ")</span>"),
      fmt_valor(ibc$valor_atual, 2),
      fmt_var(ibc$var_mes), fmt_var(ibc$var_12m)
    ),
    collapse = ""
  )

  paste0(
    '<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    "<title>Boletim Macro Semanal</title></head>",
    '<body style="margin:0;padding:20px;background:#ffffff;',
    'font:15px/1.5 -apple-system,BlinkMacSystemFont,\'Segoe UI\',Arial,sans-serif;color:#111827;">',
    '<div style="max-width:660px;margin:0 auto;">',
    '<h1 style="margin:0 0 4px;font-size:21px;color:#282f6b;">Boletim Macro Semanal</h1>',
    '<p style="margin:0 0 18px;color:#6b7280;font-size:13px;">',
    "Data de refer&#234;ncia: ", esc_html(data_ref), "</p>",
    if (!is.null(abertura)) {
      paste0(
        '<p style="margin:0 0 18px;padding:12px 14px;background:#f3f4f6;',
        'border-left:3px solid #282f6b;font-size:14px;">', abertura, "</p>"
      )
    } else {
      ""
    },
    '<table role="presentation" cellpadding="0" cellspacing="0" ',
    'style="width:100%;border-collapse:collapse;font-size:14px;">',
    '<thead><tr style="text-align:left;color:#6b7280;font-size:12px;',
    'text-transform:uppercase;letter-spacing:.03em;">',
    '<th style="', .css_celula, '">Indicador</th>',
    '<th style="', .css_num, '">&#218;ltimo valor</th>',
    '<th style="', .css_num, '">Var. m&#234;s</th>',
    '<th style="', .css_num, '">Var. 12 meses</th>',
    "</tr></thead><tbody>", linhas, "</tbody></table>",
    '<p style="margin:18px 0 0;font-size:13px;color:#6b7280;">',
    "Selic em % ao ano, varia&#231;&#245;es em p.p. C&#226;mbio em R$/US$, ",
    "cota&#231;&#227;o de fechamento; alta significa deprecia&#231;&#227;o do Real. ",
    "IBC-Br: varia&#231;&#227;o mensal pela s&#233;rie com ajuste sazonal ",
    "(SGS&#160;24364) e interanual pela original (SGS&#160;24363), ",
    "por m&#233;dia de per&#237;odo.</p>",
    '<p style="margin:16px 0 0;font-size:14px;">',
    '<a href="', URL_CONNECT, '" style="color:#282f6b;">',
    "Abrir a vers&#227;o completa, com os gr&#225;ficos</a>",
    '<span style="color:#6b7280;"> &#183; o boletim tamb&#233;m vai anexado a este e-mail.</span></p>',
    '<p style="margin:20px 0 0;font-size:12px;color:#9ca3af;border-top:1px solid #e5e7eb;padding-top:12px;">',
    "Fonte: Banco Central do Brasil &#8212; SGS. IPCA (433), c&#226;mbio (1), ",
    "Selic meta (432), IBC-Br original (24363) e com ajuste sazonal (24364). ",
    "Nenhum valor &#233; estimado ou interpolado.</p>",
    "</div></body></html>"
  )
}


# ── Execução por linha de comando ────────────────────────────────────────

# Só executa quando o arquivo É o script invocado, nunca quando é apenas
# carregado por `source()`.
#
# A primeira versão usava `identical(environment(), globalenv())`, que é
# VERDADEIRO também sob `source()` — e os testes, que carregam este arquivo
# para chamar `montar_corpo()`, passaram a gravar um `corpo-email.html` solto
# dentro de `tests/testthat/` a cada execução.
.invocado_como_script <- function() {
  arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(arg) == 0) {
    return(FALSE)
  }
  identical(
    basename(normalizePath(sub("^--file=", "", arg[1]), mustWork = FALSE)),
    "corpo_email.R"
  )
}

if (.invocado_como_script()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) >= 1 && nzchar(args[1])) {
    data_ref <- args[1]
  } else {
    data_ref <- as.character(Sys.Date())
  }
  saida <- if (length(args) >= 2 && nzchar(args[2])) args[2] else "corpo-email.html"

  html <- montar_corpo(data_ref)
  writeLines(html, saida, useBytes = TRUE)

  bytes <- file.size(saida)
  cat(sprintf(
    "corpo-email.html gerado: %.1f KB (limite do Gmail: %.0f KB)\n",
    bytes / 1024, LIMITE_GMAIL_BYTES / 1024
  ))
  if (bytes >= LIMITE_GMAIL_BYTES) {
    stop(
      "Corpo do e-mail acima do limite de truncamento do Gmail. ",
      "O ponto deste arquivo era ficar abaixo dele.",
      call. = FALSE
    )
  }
}
