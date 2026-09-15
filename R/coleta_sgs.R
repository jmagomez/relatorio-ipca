# Coleta das séries SGS do Banco Central.
#
# Por que este arquivo foi reescrito
# ----------------------------------
# A versão anterior era um script de rascunho que ficou versionado:
#
#   dir_dados <- "/home/runner/work/relatorio-ipca/relatorio-ipca/output/dados"
#   data_ref  <- as.Date("2026-07-28")
#
# Caminho absoluto do runner do GitHub Actions (quebra em qualquer outra
# máquina) e data de referência congelada em julho — toda execução posterior
# coletava contra uma data velha sem avisar.
#
# Agora: funções puras, caminhos relativos à raiz do projeto e data de
# referência vinda de argumento. Nenhum valor de ambiente gravado no código.

library(dplyr)

#' Garante que o `rbcb` está disponível, com mensagem acionável
#'
#' `library(rbcb)` no topo do arquivo impediria carregar até as funções puras
#' daqui (`raiz_projeto()`, `validar_e_limpar()`) numa máquina sem o pacote —
#' e são justamente elas que os testes exercitam sem tocar a rede.
exigir_rbcb <- function() {
  if (!requireNamespace("rbcb", quietly = TRUE)) {
    stop(
      "Pacote 'rbcb' nao instalado. Rode: install.packages('rbcb')",
      call. = FALSE
    )
  }
}

# ── Catálogo de séries ──────────────────────────────────────────────
#
# Um único lugar declara o que é coletado. `janela_dias` existe porque a API
# SGS rejeita consulta a série DIÁRIA sem filtro de data (devolve um JSON de
# erro com ~3 campos, não os dados) e limita cada consulta a 10 anos.

SERIES_SGS <- data.frame(
  chave       = c("ipca", "cambio", "selic", "ibcbr", "ibcbr_sa"),
  codigo      = c(433L, 1L, 432L, 24363L, 24364L),
  descricao   = c(
    "IPCA - variação mensal",
    "Câmbio R$/US$ - venda, fechamento",
    "Selic meta definida pelo Copom",
    "IBC-Br - série original",
    "IBC-Br - com ajuste sazonal"
  ),
  janela_dias = c(NA, 730, 730, NA, NA),
  stringsAsFactors = FALSE
)

#' Raiz do projeto: sobe a árvore até encontrar `_quarto.yml`
#'
#' Substitui os caminhos absolutos do runner. Funciona na máquina do
#' desenvolvedor, no CI e em qualquer diretório de trabalho.
raiz_projeto <- function(inicio = getwd()) {
  caminho <- normalizePath(inicio, mustWork = FALSE)
  while (!file.exists(file.path(caminho, "_quarto.yml")) &&
    dirname(caminho) != caminho) {
    caminho <- dirname(caminho)
  }
  caminho
}


#' Valida a resposta do SGS e normaliza para (data, valor)
#'
#' A API às vezes devolve HTTP 200 com um objeto de erro no corpo. Aceitar isso
#' como dado é o modo de falha que produz série vazia sem ninguém perceber.
#'
#' @param dados Resultado de `rbcb::get_series()`.
#' @param codigo Código da série, usado para localizar a coluna de valor.
#' @return Tibble com `data` (Date) e `valor` (num), ou NULL se inválido.
validar_e_limpar <- function(dados, codigo) {
  if (is.null(dados) || !is.data.frame(dados) || nrow(dados) == 0L) {
    return(NULL)
  }

  nomes <- names(dados)
  if (!("date" %in% nomes) && !("data" %in% tolower(nomes))) {
    return(NULL)
  }

  col_valor <- as.character(codigo)
  if (!(col_valor %in% nomes)) {
    if (ncol(dados) < 2L) {
      return(NULL)
    }
    col_valor <- nomes[2]
  }

  limpo <- dados |>
    dplyr::select(date = dplyr::starts_with("date"), valor = dplyr::all_of(col_valor)) |>
    dplyr::mutate(data = as.Date(date), valor = as.numeric(valor)) |>
    dplyr::select(data, valor) |>
    dplyr::filter(!is.na(data)) |>
    dplyr::arrange(data)

  if (nrow(limpo) == 0L || all(is.na(limpo$valor))) {
    return(NULL)
  }
  limpo
}


#' Coleta uma série do SGS e grava o CSV
#'
#' @param codigo Código SGS.
#' @param arquivo_saida Caminho do CSV de destino.
#' @param data_ref Data de referência (fim da janela).
#' @param janela_dias Tamanho da janela retroativa; NA coleta a série inteira.
#' @return Lista com `codigo`, `status`, `linhas`, `primeira_data`,
#'   `ultima_data` e `ultimo_valor`.
coletar_serie <- function(codigo, arquivo_saida, data_ref = Sys.Date(),
                          janela_dias = NA_integer_) {
  resultado <- list(
    codigo = codigo, status = "falha", linhas = 0L,
    primeira_data = NA_character_, ultima_data = NA_character_,
    ultimo_valor = NA_real_, mensagem = NA_character_
  )

  exigir_rbcb()

  dados <- tryCatch(
    {
      if (is.na(janela_dias)) {
        rbcb::get_series(codigo)
      } else {
        rbcb::get_series(codigo, start_date = as.Date(data_ref) - janela_dias)
      }
    },
    error = function(e) {
      resultado$mensagem <<- conditionMessage(e)
      NULL
    }
  )

  limpo <- validar_e_limpar(dados, codigo)
  if (is.null(limpo)) {
    if (is.na(resultado$mensagem)) {
      resultado$mensagem <- "resposta vazia ou fora do formato esperado"
    }
    return(resultado)
  }

  dir.create(dirname(arquivo_saida), showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(limpo, arquivo_saida, row.names = FALSE, quote = FALSE)

  resultado$status        <- "sucesso"
  resultado$linhas        <- nrow(limpo)
  resultado$primeira_data <- as.character(min(limpo$data))
  resultado$ultima_data   <- as.character(max(limpo$data))
  resultado$ultimo_valor  <- dplyr::last(limpo$valor)
  resultado$mensagem      <- NA_character_
  resultado
}


#' Coleta todas as séries do catálogo
#'
#' Política de falha do projeto: **por série, não global**. Uma fonte fora do ar
#' não impede as demais; o relatório trata o indicador ausente como
#' "indisponível nesta semana". Só o fracasso de todas encerra com erro.
#'
#' @param data_ref Data de referência.
#' @param dir_dados Diretório de destino dos CSVs.
#' @param dir_logs Diretório do registro de erros.
#' @return Data frame com uma linha por série coletada.
coletar_todas <- function(data_ref = Sys.Date(),
                          dir_dados = file.path(raiz_projeto(), "output", "dados"),
                          dir_logs = file.path(raiz_projeto(), "logs")) {
  dir.create(dir_dados, showWarnings = FALSE, recursive = TRUE)
  dir.create(dir_logs, showWarnings = FALSE, recursive = TRUE)

  arquivo_erros <- file.path(dir_logs, "erros.md")
  if (file.exists(arquivo_erros)) file.remove(arquivo_erros)

  message("=== Coleta SGS — referência ", data_ref, " ===")

  linhas <- lapply(seq_len(nrow(SERIES_SGS)), function(i) {
    serie <- SERIES_SGS[i, ]
    message("  SGS ", serie$codigo, " (", serie$descricao, ")")

    res <- coletar_serie(
      codigo        = serie$codigo,
      arquivo_saida = file.path(dir_dados, paste0(serie$chave, ".csv")),
      data_ref      = data_ref,
      janela_dias   = serie$janela_dias
    )

    if (res$status == "sucesso") {
      message(sprintf(
        "    ok: %d linhas (%s a %s), último valor %s",
        res$linhas, res$primeira_data, res$ultima_data, format(res$ultimo_valor)
      ))
    } else {
      message("    FALHA: ", res$mensagem)
      cat(sprintf("- **SGS %d** (%s): %s\n", serie$codigo, serie$descricao, res$mensagem),
        file = arquivo_erros, append = TRUE
      )
    }

    data.frame(
      chave = serie$chave, codigo = serie$codigo, status = res$status,
      linhas = res$linhas, ultima_data = res$ultima_data,
      ultimo_valor = res$ultimo_valor, stringsAsFactors = FALSE
    )
  })

  resumo <- do.call(rbind, linhas)
  falhas <- sum(resumo$status != "sucesso")

  if (falhas == nrow(resumo)) {
    stop("Todas as séries falharam. Ver ", arquivo_erros)
  }
  if (falhas > 0L) {
    warning(falhas, " série(s) falharam. Ver ", arquivo_erros)
  }
  resumo
}


# Execução como script: `Rscript R/coleta_sgs.R [AAAA-MM-DD]`
if (identical(environment(), globalenv()) && sys.nframe() == 0L) {
  argumentos <- commandArgs(trailingOnly = TRUE)
  ref <- if (length(argumentos) >= 1L && nzchar(argumentos[1])) {
    as.Date(argumentos[1])
  } else {
    Sys.Date()
  }
  print(coletar_todas(data_ref = ref))
}
