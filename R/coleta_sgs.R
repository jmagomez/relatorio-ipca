# Script para coleta de séries SGS do Banco Central do Brasil
# Data de referência: 2026-07-27

library(rbcb)
library(dplyr)

# Configurações
data_ref <- as.Date("2026-07-28")
dir_dados <- "/home/runner/work/relatorio-ipca/relatorio-ipca/output/dados"
dir_logs <- "/home/runner/work/relatorio-ipca/relatorio-ipca/logs"
arquivo_erros <- file.path(dir_logs, "erros.md")

# Garantir que diretórios existem
dir.create(dir_dados, showWarnings = FALSE, recursive = TRUE)
dir.create(dir_logs, showWarnings = FALSE, recursive = TRUE)

# Função para limpar e validar dados
validar_e_limpar <- function(dados, codigo_serie) {
  # Verificar se é resposta de erro da API
  if (is.null(dados)) {
    return(NULL)
  }

  # Verificar se tem dados
  if (!is.data.frame(dados) || nrow(dados) == 0) {
    return(NULL)
  }

  # Esperar colunas: date e coluna do código (como string)
  nomes <- names(dados)

  if (!("date" %in% nomes) && !"data" %in% tolower(nomes)) {
    return(NULL)
  }

  # Encontrar coluna de valor (será o número da série como string)
  col_valor <- as.character(codigo_serie)
  if (!(col_valor %in% nomes)) {
    # Tenta coluna 2 se o nome não for exato
    if (ncol(dados) >= 2) {
      col_valor <- names(dados)[2]
    } else {
      return(NULL)
    }
  }

  # Renomear colunas para data e valor
  dados <- dados %>%
    select(date = starts_with("date"), valor = all_of(col_valor))

  # Converter data para Date e valor para numérico
  dados <- dados %>%
    mutate(
      data = as.Date(date),
      valor = as.numeric(valor)
    ) %>%
    select(data, valor) %>%
    arrange(data)

  return(dados)
}

# Função para registrar erro
registrar_erro <- function(codigo, mensagem, url_params = "") {
  linha <- sprintf("- **SGS %d**: %s %s\n", codigo, mensagem, url_params)
  cat(linha, file = arquivo_erros, append = TRUE)
}

# Função para coletar e processar série
coletar_serie <- function(codigo, arquivo_saida, start_date = NULL) {
  resultado <- list(
    codigo = codigo,
    status = "falha",
    linhas = 0,
    primeira_data = NA,
    ultima_data = NA,
    ultimo_valor = NA
  )

  tryCatch({
    # Coletar dados
    if (!is.null(start_date)) {
      cat(sprintf("Coletando SGS %d (com start_date = %s)...\n", codigo, start_date))
      dados <- rbcb::get_series(codigo, start_date = as.Date(start_date))
    } else {
      cat(sprintf("Coletando SGS %d...\n", codigo))
      dados <- rbcb::get_series(codigo)
    }

    # Validar
    dados_limpo <- validar_e_limpar(dados, codigo)

    if (is.null(dados_limpo)) {
      registrar_erro(codigo, "Falha ao validar ou coletar dados",
                     sprintf("(start_date: %s)", ifelse(is.null(start_date), "none", start_date)))
      cat(sprintf("  ERRO: Falha ao coletar SGS %d\n", codigo))
      return(resultado)
    }

    # Salvar CSV
    write.csv(dados_limpo, arquivo_saida, row.names = FALSE, quote = FALSE)

    # Preencher resultado
    resultado$status <- "sucesso"
    resultado$linhas <- nrow(dados_limpo)
    resultado$primeira_data <- as.character(min(dados_limpo$data))
    resultado$ultima_data <- as.character(max(dados_limpo$data))
    resultado$ultimo_valor <- dados_limpo %>%
      filter(data == max(data)) %>%
      pull(valor) %>%
      first()

    cat(sprintf("  OK: %d linhas (%s a %s)\n",
                resultado$linhas, resultado$primeira_data, resultado$ultima_data))

  }, error = function(e) {
    registrar_erro(codigo, paste("Erro R:", as.character(e)))
    cat(sprintf("  ERRO R: %s\n", as.character(e)))
  })

  return(resultado)
}

# Limpar arquivo de erros anterior
if (file.exists(arquivo_erros)) {
  file.remove(arquivo_erros)
}

# Coletar séries
cat("\n=== COLETA DE SÉRIES SGS ===\n")
cat(sprintf("Data de referência: %s\n\n", data_ref))

start_date_730 <- data_ref - 730

resultados <- list()

# SGS 433 - IPCA (mensal)
resultados$ipca <- coletar_serie(
  433,
  file.path(dir_dados, "ipca.csv")
)

# SGS 1 - Câmbio (diária, últimos 2 anos)
resultados$cambio <- coletar_serie(
  1,
  file.path(dir_dados, "cambio.csv"),
  start_date = start_date_730
)

# SGS 432 - Selic (diária, últimos 2 anos)
resultados$selic <- coletar_serie(
  432,
  file.path(dir_dados, "selic.csv"),
  start_date = start_date_730
)

# SGS 24363 - IBC-Br (mensal, original)
resultados$ibcbr <- coletar_serie(
  24363,
  file.path(dir_dados, "ibcbr.csv")
)

# SGS 24364 - IBC-Br (mensal, ajuste sazonal)
resultados$ibcbr_sa <- coletar_serie(
  24364,
  file.path(dir_dados, "ibcbr_sa.csv")
)

# Relatório final
cat("\n=== RESUMO ===\n\n")

todos_sucesso <- TRUE
for (nome in names(resultados)) {
  res <- resultados[[nome]]
  status_str <- ifelse(res$status == "sucesso", "OK", "ERRO")
  cat(sprintf("[%s] %s (SGS %d):\n", status_str, toupper(nome), res$codigo))
  cat(sprintf("  Status: %s\n", res$status))
  if (res$status == "sucesso") {
    cat(sprintf("  Linhas: %d\n", res$linhas))
    cat(sprintf("  Período: %s a %s\n", res$primeira_data, res$ultima_data))
    cat(sprintf("  Último valor: %s\n", res$ultimo_valor))
  }
  cat("\n")

  if (res$status != "sucesso") {
    todos_sucesso <- FALSE
  }
}

# Verificar se todas as séries falharam
if (!todos_sucesso) {
  cat("AVISO: Uma ou mais séries falharam. Verificar logs/erros.md\n")

  # Verificar se TODAS falharam
  num_falhas <- sum(sapply(resultados, function(x) x$status != "sucesso"))
  if (num_falhas == length(resultados)) {
    cat("CRÍTICO: TODAS as séries falharam!\n")
    quit(status = 1)
  }
}

cat("\nColeta finalizada\n")
