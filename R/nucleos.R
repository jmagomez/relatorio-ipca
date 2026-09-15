# Medidas de núcleo e difusão do IPCA.
#
# Duas camadas, com graus de confiança diferentes — e a distinção é deliberada:
#
# 1. **Derivadas dos microdados do SIDRA** (difusão e média aparada entre
#    grupos). Calculadas a partir da tabela 7060, que o projeto já consome.
#    Totalmente reproduzíveis e verificáveis; entram no relatório por padrão.
#
# 2. **Núcleos oficiais do Banco Central** (SGS). Prontos e mais precisos, mas
#    dependem de o código de cada série estar correto — e não há endpoint
#    público que devolva o NOME de uma série do SGS em JSON para conferir.
#    A saída aqui não é confiar no código nem desligar a camada: é **verificar
#    a identidade pelo comportamento**. Toda série coletada tem de exibir as
#    propriedades estruturais de um núcleo do IPCA (mensal, ordem de grandeza
#    de variação de preço, menos volátil que o índice cheio e correlacionada
#    com ele) antes de ser publicada. Série que não passa é descartada com
#    aviso, e o rótulo publicado sempre carrega o código SGS à vista.

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
# Camada 2 — núcleos oficiais do SGS, com verificação de identidade
# ══════════════════════════════════════════════════════════════════════════════

#' Catálogo dos núcleos oficiais do Banco Central.
#'
#' Os códigos abaixo são o melhor conhecimento disponível, **mas o código não
#' confia neles**. Toda série coletada passa por `validar_serie_nucleo()` antes
#' de entrar no relatório: se o código apontar para outra coisa — um índice de
#' nível, uma série anual, outro indicador —, ela é descartada com aviso, e o
#' relatório segue com as medidas derivadas do SIDRA.
#'
#' O rótulo publicado sempre carrega o código SGS entre parênteses, para que o
#' leitor possa auditar a origem de cada linha.
NUCLEOS_SGS <- data.frame(
  chave = c("ms", "ex0", "ex3", "dp", "p55"),
  codigo = c(4466L, 11427L, 27839L, 16122L, 28751L),
  descricao = c(
    "Médias aparadas com suavização",
    "Exclusão EX0",
    "Exclusão EX3",
    "Dupla ponderação",
    "Percentil 55"
  ),
  stringsAsFactors = FALSE
)

#' Rótulo de exibição, sempre com o código SGS à vista
rotulo_nucleo <- function(descricao, codigo) {
  paste0(descricao, " (SGS ", codigo, ")")
}


#' Verifica se uma série tem as propriedades estruturais de um núcleo do IPCA
#'
#' Não existe endpoint público que devolva o nome de uma série do SGS em JSON,
#' então a identidade é verificada pelo comportamento, não pelo rótulo. Um
#' núcleo de inflação ao consumidor satisfaz, por construção, cinco
#' propriedades — e uma série trocada falha em pelo menos uma delas:
#'
#' 1. **Frequência mensal.** Série diária ou anual é outra coisa.
#' 2. **Ordem de grandeza de variação mensal.** Fora de ±5% ao mês não é
#'    variação percentual de preço ao consumidor; é nível de índice, acumulado
#'    em 12 meses ou outra unidade.
#' 3. **Sobreposição suficiente** com o IPCA cheio para comparar.
#' 4. **Volatilidade menor que a do índice cheio.** É a propriedade que
#'    *define* um núcleo: ele existe para remover a cauda volátil. Um núcleo
#'    mais volátil que o cheio não é núcleo.
#' 5. **Correlação positiva com o índice cheio.** Mede o mesmo fenômeno; se
#'    não anda junto, é outro indicador.
#'
#' @param df_serie Tibble com `data` (Date) e `valor` (num).
#' @param df_ipca Tibble com `data` e `ipca_mm`, o índice cheio de referência.
#' @param min_meses Sobreposição mínima exigida. Padrão: 24.
#' @return Lista com `ok` (logical) e `motivos` (character): as checagens que
#'   falharam, vazias quando a série passa.
validar_serie_nucleo <- function(df_serie, df_ipca, min_meses = 24L) {
  motivos <- character()

  if (is.null(df_serie) || !is.data.frame(df_serie) || nrow(df_serie) < min_meses) {
    return(list(ok = FALSE, motivos = "série vazia ou curta demais"))
  }

  df_serie <- df_serie[!is.na(df_serie$valor), ]
  df_serie <- df_serie[order(df_serie$data), ]

  # 1. Frequência mensal: mediana do intervalo entre observações entre 26 e 32 dias.
  intervalos <- as.numeric(diff(df_serie$data))
  if (length(intervalos) == 0L || stats::median(intervalos) < 26 ||
    stats::median(intervalos) > 32) {
    motivos <- c(motivos, "não é série mensal")
  }

  # 2. Ordem de grandeza compatível com variação percentual mensal de preços.
  if (max(abs(df_serie$valor), na.rm = TRUE) > 5) {
    motivos <- c(motivos, "valores fora da faixa de variação mensal (±5%)")
  }

  # 3 a 5 exigem sobreposição com o índice cheio.
  juncao <- merge(
    df_serie[, c("data", "valor")],
    df_ipca[, c("data", "ipca_mm")],
    by = "data"
  )
  juncao <- juncao[stats::complete.cases(juncao), ]

  if (nrow(juncao) < min_meses) {
    motivos <- c(motivos, "sobreposição insuficiente com o IPCA cheio")
    return(list(ok = length(motivos) == 0L, motivos = motivos))
  }

  desvio_nucleo <- stats::sd(juncao$valor)
  desvio_cheio <- stats::sd(juncao$ipca_mm)
  if (!is.finite(desvio_nucleo) || !is.finite(desvio_cheio) ||
    desvio_nucleo >= desvio_cheio) {
    motivos <- c(motivos, "volatilidade não menor que a do índice cheio")
  }

  correlacao <- suppressWarnings(stats::cor(juncao$valor, juncao$ipca_mm))
  if (!is.finite(correlacao) || correlacao < 0.3) {
    motivos <- c(motivos, "correlação fraca com o índice cheio")
  }

  list(ok = length(motivos) == 0L, motivos = motivos)
}


#' Coleta os núcleos oficiais, descartando os que não passam na verificação
#'
#' Falha por série, nunca global: um núcleo reprovado ou indisponível não
#' impede os demais, e nenhum impede o relatório. O retorno traz uma coluna
#' `rotulo` já pronta para exibição, com o código SGS embutido.
#'
#' @param df_ipca Tibble com `data` e `ipca_mm`, usado na verificação.
#' @param desde Data inicial da coleta.
#' @param verificar Quando FALSE, pula a verificação estrutural. Use apenas em
#'   diagnóstico — o relatório sempre verifica.
#' @return Tibble com `data`, `chave`, `codigo`, `rotulo` e `valor`.
coletar_nucleos_oficiais <- function(df_ipca, desde = as.Date("2015-01-01"),
                                     verificar = TRUE) {
  vazio <- data.frame(
    data = as.Date(character()), chave = character(), codigo = integer(),
    rotulo = character(), valor = numeric(), stringsAsFactors = FALSE
  )

  if (!requireNamespace("rbcb", quietly = TRUE)) {
    warning("Pacote 'rbcb' ausente: núcleos oficiais não coletados.")
    return(vazio)
  }

  partes <- lapply(seq_len(nrow(NUCLEOS_SGS)), function(i) {
    serie <- NUCLEOS_SGS[i, ]

    bruto <- tryCatch(
      rbcb::get_series(serie$codigo, start_date = as.Date(desde)),
      error = function(e) NULL
    )
    if (is.null(bruto) || !is.data.frame(bruto) || nrow(bruto) == 0L) {
      warning("Núcleo ", serie$chave, " (SGS ", serie$codigo, ") indisponível.")
      return(NULL)
    }

    df <- data.frame(
      data = as.Date(bruto[[1]]),
      valor = as.numeric(bruto[[2]]),
      stringsAsFactors = FALSE
    )

    if (verificar) {
      exame <- validar_serie_nucleo(df, df_ipca)
      if (!exame$ok) {
        warning(
          "Núcleo ", serie$chave, " (SGS ", serie$codigo,
          ") descartado — não tem as propriedades de um núcleo do IPCA: ",
          paste(exame$motivos, collapse = "; "),
          ". Confira o código em https://www3.bcb.gov.br/sgspub/"
        )
        return(NULL)
      }
    }

    data.frame(
      data = df$data,
      chave = serie$chave,
      codigo = serie$codigo,
      rotulo = rotulo_nucleo(serie$descricao, serie$codigo),
      valor = df$valor,
      stringsAsFactors = FALSE
    )
  })

  partes <- Filter(Negate(is.null), partes)
  if (length(partes) == 0L) {
    message(
      "Nenhum núcleo oficial passou na verificação — o relatório segue com as ",
      "medidas derivadas do SIDRA."
    )
    return(vazio)
  }
  do.call(rbind, partes) |> dplyr::arrange(data, chave)
}


#' Diagnóstico do catálogo: o que cada código devolve e se passa na verificação
#'
#' Não publica nada. Serve para conferência humana antes de confiar no gráfico.
#'
#' @param df_ipca Índice cheio de referência.
#' @param desde Data inicial da amostra.
#' @return Data frame com um veredito por série.
validar_catalogo_nucleos <- function(df_ipca, desde = as.Date("2015-01-01")) {
  linhas <- lapply(seq_len(nrow(NUCLEOS_SGS)), function(i) {
    serie <- NUCLEOS_SGS[i, ]
    bruto <- tryCatch(
      rbcb::get_series(serie$codigo, start_date = as.Date(desde)),
      error = function(e) NULL
    )

    if (is.null(bruto) || !is.data.frame(bruto) || nrow(bruto) == 0L) {
      return(data.frame(
        chave = serie$chave, codigo = serie$codigo, n = 0L,
        ultimo = NA_real_, aprovado = FALSE, motivos = "sem dados",
        stringsAsFactors = FALSE
      ))
    }

    df <- data.frame(data = as.Date(bruto[[1]]), valor = as.numeric(bruto[[2]]))
    exame <- validar_serie_nucleo(df, df_ipca)

    data.frame(
      chave = serie$chave, codigo = serie$codigo, n = nrow(df),
      ultimo = dplyr::last(df$valor[!is.na(df$valor)]),
      aprovado = exame$ok,
      motivos = if (length(exame$motivos)) paste(exame$motivos, collapse = "; ") else "",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, linhas)
}
