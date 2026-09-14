# Medidas de núcleo e difusão do IPCA.
#
# Duas camadas, com graus de confiança diferentes — e a distinção é deliberada:
#
# 1. **Derivadas dos microdados do SIDRA** (difusão e média aparada entre
#    grupos). Calculadas a partir da tabela 7060, que o projeto já consome.
#    Totalmente reproduzíveis e verificáveis; entram no relatório por padrão.
#
# 2. **Núcleos oficiais do Banco Central** (SGS). Prontos e mais precisos, mas
#    dependem de o código de cada série estar correto. O catálogo abaixo está
#    **desligado por padrão**: publicar uma série macroeconômica com o rótulo
#    errado é pior do que não publicá-la. Rode `validar_catalogo_nucleos()`,
#    confira nome e ordem de grandeza de cada série, e então ligue.

library(dplyr)

# ══════════════════════════════════════════════════════════════════════════════
# Camada 1 — derivadas do SIDRA (prontas para uso)
# ══════════════════════════════════════════════════════════════════════════════

#' Difusão entre os grupos do IPCA
#'
#' Proporção dos nove grupos de despesa com variação positiva no mês.
#'
#' **Leia pelo que é.** Difusão entre nove grupos é mais grossa do que a difusão
#' entre os 377 subitens que o Banco Central acompanha: um grupo inteiro pode
#' subir por causa de um único item. Serve para distinguir alta concentrada de
#' alta disseminada, não para substituir a difusão oficial. O rótulo no
#' relatório diz "entre os nove grupos" por esse motivo.
#'
#' @param df_grupos Tibble de `coletar_ipca_grupos()`: `data`, `grupo`,
#'   `variacao`, `peso`.
#' @return Tibble com `data`, `n_itens`, `n_positivos`, `difusao`.
difusao_por_grupo <- function(df_grupos) {
  df_grupos |>
    dplyr::rename(item = grupo) |>
    calcular_difusao()
}


#' Média aparada entre os grupos do IPCA
#'
#' Apara `corte`% do peso em cada cauda da distribuição de variações dos grupos
#' e devolve a média ponderada do miolo.
#'
#' **Não é o IPCA-MS do Banco Central.** O núcleo oficial apara a distribuição
#' dos 377 subitens e suaviza itens de reajuste infrequente. Esta medida apara
#' nove grupos e não suaviza nada — é uma verificação independente, robusta a
#' choque concentrado em um grupo, e continua disponível quando o SGS falha.
#'
#' @param df_grupos Saída de `coletar_ipca_grupos()`.
#' @param corte Percentual de peso aparado em cada cauda. Padrão: 20.
#' @return Tibble com `data`, `nucleo_aparado`, `peso_utilizado`.
media_aparada_por_grupo <- function(df_grupos, corte = 20) {
  df_grupos |>
    dplyr::rename(item = grupo) |>
    calcular_media_aparada(corte = corte)
}


#' Junta o índice cheio às medidas derivadas, mês a mês
#'
#' @param df_ipca Tibble com `data` e `ipca_mm`.
#' @param df_grupos Saída de `coletar_ipca_grupos()`.
#' @param corte Corte da média aparada.
#' @return Tibble com `data`, `ipca_mm`, `nucleo_aparado` e `difusao`.
consolidar_nucleos <- function(df_ipca, df_grupos, corte = 20) {
  aparada <- media_aparada_por_grupo(df_grupos, corte = corte)
  difusao <- difusao_por_grupo(df_grupos)

  df_ipca |>
    dplyr::select(data, ipca_mm) |>
    dplyr::left_join(dplyr::select(aparada, data, nucleo_aparado), by = "data") |>
    dplyr::left_join(dplyr::select(difusao, data, difusao), by = "data") |>
    dplyr::arrange(data)
}


# ══════════════════════════════════════════════════════════════════════════════
# Camada 2 — núcleos oficiais do SGS (requer confirmação antes de ligar)
# ══════════════════════════════════════════════════════════════════════════════

#' Catálogo dos núcleos oficiais.
#'
#' `confirmado` indica se o código foi verificado contra o SGS **neste
#' repositório**. Enquanto for FALSE, `coletar_nucleos_oficiais()` ignora a
#' linha. Para confirmar: rode `validar_catalogo_nucleos()`, confira na consulta
#' pública do SGS (https://www3.bcb.gov.br/sgspub/) que o código corresponde ao
#' núcleo descrito, e marque TRUE.
NUCLEOS_SGS <- data.frame(
  chave = c("ms", "ex0", "ex3", "dp", "p55"),
  codigo = c(4466L, 11427L, 27839L, 16122L, 28751L),
  descricao = c(
    "IPCA núcleo médias aparadas com suavização (IPCA-MS)",
    "IPCA núcleo por exclusão EX0",
    "IPCA núcleo por exclusão EX3",
    "IPCA núcleo de dupla ponderação",
    "IPCA núcleo percentil 55 (P55)"
  ),
  confirmado = c(FALSE, FALSE, FALSE, FALSE, FALSE),
  stringsAsFactors = FALSE
)


#' Consulta cada núcleo do catálogo e reporta o que voltou
#'
#' Não publica nada: imprime número de observações, período coberto e os
#' últimos valores, para conferência humana do código de cada série.
#'
#' @param desde Data inicial da amostra de verificação.
#' @return Data frame com o diagnóstico por série.
validar_catalogo_nucleos <- function(desde = Sys.Date() - 400) {
  linhas <- lapply(seq_len(nrow(NUCLEOS_SGS)), function(i) {
    serie <- NUCLEOS_SGS[i, ]
    dados <- tryCatch(
      rbcb::get_series(serie$codigo, start_date = as.Date(desde)),
      error = function(e) NULL
    )

    if (is.null(dados) || !is.data.frame(dados) || nrow(dados) == 0L) {
      return(data.frame(
        chave = serie$chave, codigo = serie$codigo, status = "sem dados",
        n = 0L, ultimo = NA_real_, plausivel = NA, stringsAsFactors = FALSE
      ))
    }

    valores <- as.numeric(dados[[2]])
    ultimo <- dplyr::last(valores[!is.na(valores)])
    # Um núcleo do IPCA é variação percentual MENSAL: fora de [-3, 5] quase
    # certamente é outra série (nível de índice, acumulado, outra unidade).
    plausivel <- !is.na(ultimo) && ultimo > -3 && ultimo < 5

    data.frame(
      chave = serie$chave, codigo = serie$codigo, status = "ok",
      n = nrow(dados), ultimo = ultimo, plausivel = plausivel,
      stringsAsFactors = FALSE
    )
  })

  resumo <- do.call(rbind, linhas)
  message(
    "Confira cada linha contra https://www3.bcb.gov.br/sgspub/ antes de marcar ",
    "`confirmado = TRUE` em NUCLEOS_SGS. `plausivel = FALSE` indica série que ",
    "não é variação percentual mensal."
  )
  resumo
}


#' Coleta os núcleos oficiais marcados como confirmados
#'
#' Enquanto nenhum estiver confirmado devolve um tibble vazio, e o relatório
#' segue com as medidas derivadas do SIDRA. Falha por série, nunca global.
#'
#' @param desde Data inicial.
#' @return Tibble com `data`, `chave`, `descricao`, `valor`.
coletar_nucleos_oficiais <- function(desde = as.Date("2015-01-01")) {
  confirmados <- NUCLEOS_SGS[NUCLEOS_SGS$confirmado, , drop = FALSE]

  if (nrow(confirmados) == 0L) {
    message(
      "Nenhum núcleo oficial confirmado em NUCLEOS_SGS — o relatório usa ",
      "apenas as medidas derivadas do SIDRA. Rode validar_catalogo_nucleos()."
    )
    return(data.frame(
      data = as.Date(character()), chave = character(),
      descricao = character(), valor = numeric(), stringsAsFactors = FALSE
    ))
  }

  partes <- lapply(seq_len(nrow(confirmados)), function(i) {
    serie <- confirmados[i, ]
    dados <- tryCatch(
      rbcb::get_series(serie$codigo, start_date = as.Date(desde)),
      error = function(e) NULL
    )
    if (is.null(dados) || !is.data.frame(dados) || nrow(dados) == 0L) {
      warning("Núcleo ", serie$chave, " (SGS ", serie$codigo, ") indisponível.")
      return(NULL)
    }
    data.frame(
      data = as.Date(dados[[1]]),
      chave = serie$chave,
      descricao = serie$descricao,
      valor = as.numeric(dados[[2]]),
      stringsAsFactors = FALSE
    )
  })

  partes <- Filter(Negate(is.null), partes)
  if (length(partes) == 0L) {
    return(data.frame(
      data = as.Date(character()), chave = character(),
      descricao = character(), valor = numeric(), stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, partes) |> dplyr::arrange(data, chave)
}
