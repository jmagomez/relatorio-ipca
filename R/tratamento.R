# Funções puras de tratamento e preparação dos dados do IPCA

library(dplyr)
library(tidyr)
library(lubridate)
library(slider)

#' Calcula o IPCA acumulado em 12 meses via janela móvel
#'
#' Aplica a fórmula de capitalização composta sobre uma janela deslizante de
#' 12 observações mensais: (prod(1 + x_i/100) - 1) * 100.
#' Os primeiros 11 meses recebem NA por janela incompleta.
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm` (variação % mensal).
#' @return O mesmo tibble com coluna adicional `acum_12m` (%).
calcular_acumulado_12m <- function(df) {
  df |>
    dplyr::arrange(data) |>
    dplyr::mutate(
      acum_12m = slider::slide_dbl(
        ipca_mm,
        .f        = ~ (prod(1 + .x / 100) - 1) * 100,
        .before   = 11,
        .complete = TRUE
      )
    )
}


#' Calcula o IPCA acumulado no ano calendário
#'
#' Reinicia o acúmulo em janeiro de cada ano. Para cada mês, retorna o
#' produto encadeado de todos os meses anteriores do mesmo ano, inclusive
#' o próprio mês: (cumprod(1 + x_i/100) - 1) * 100.
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm` (variação % mensal).
#' @return O mesmo tibble com coluna adicional `acum_ano` (%).
calcular_acumulado_ano <- function(df) {
  df |>
    dplyr::arrange(data) |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::group_by(ano) |>
    dplyr::mutate(
      acum_ano = (cumprod(1 + ipca_mm / 100) - 1) * 100
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-ano)
}


#' Prepara dados para o gráfico sazonal (sobreposição de anos)
#'
#' Extrai mês e ano de cada observação e marca o ano mais recente como
#' destaque. A coluna `ano` retornada como fator ordenado permite que o
#' ggplot2 mapeie cores automaticamente, reservando a camada de destaque
#' para o ano corrente.
#'
#' @param df Tibble com colunas `data` (Date) e `ipca_mm`.
#' @param ano_inicio Primeiro ano a incluir na série. Padrão: 2015.
#' @return Tibble com colunas `mes` (int 1–12), `ano` (fator ordenado),
#'   `ipca_mm` e `destaque` (logical TRUE para o ano mais recente).
preparar_sazonal <- function(df, ano_inicio = 2015) {
  ano_corrente <- lubridate::year(max(df$data, na.rm = TRUE))

  df |>
    dplyr::filter(lubridate::year(data) >= ano_inicio) |>
    dplyr::mutate(
      mes      = lubridate::month(data),
      ano      = lubridate::year(data),
      destaque = ano == ano_corrente,
      ano      = factor(ano, levels = sort(unique(ano)), ordered = TRUE)
    ) |>
    dplyr::select(mes, ano, ipca_mm, destaque)
}


#' Calcula contribuições de cada grupo do IPCA para a variação mensal
#'
#' A contribuição de cada grupo é definida como:
#'   contribuicao = variacao * peso / 100
#'
#' A soma das 9 contribuições reproduz o IPCA cheio do mês. Emite aviso
#' caso qualquer mês apresente menos de 9 grupos (dados incompletos).
#'
#' Para validar a coerência, compare `sum(contribuicao)` por mês com
#' `ipca_mm` obtido via `coletar_ipca_mensal()`.
#'
#' @param df_grupos Tibble com colunas `data` (Date), `grupo` (chr),
#'   `variacao` (num) e `peso` (num), conforme retornado por
#'   `coletar_ipca_grupos()`.
#' @return Lista com dois elementos:
#'   \describe{
#'     \item{historico}{Tibble completo com coluna `contribuicao` adicionada.}
#'     \item{mes_atual}{Recorte do mês mais recente disponível.}
#'   }
preparar_contribuicoes <- function(df_grupos) {
  historico <- df_grupos |>
    dplyr::mutate(contribuicao = variacao * peso / 100)

  # sanity check: todo mês deve ter os 9 grupos
  contagem <- historico |>
    dplyr::group_by(data) |>
    dplyr::summarise(n_grupos = dplyr::n(), .groups = "drop")

  meses_incompletos <- sum(contagem$n_grupos < 9L, na.rm = TRUE)
  if (meses_incompletos > 0L) {
    warning(sprintf(
      paste0(
        "%d mês(es) com menos de 9 grupos. ",
        "A soma das contribuições ficará subestimada nesses períodos."
      ),
      meses_incompletos
    ))
  }

  data_atual <- max(historico$data, na.rm = TRUE)
  mes_atual  <- dplyr::filter(historico, data == data_atual)

  list(historico = historico, mes_atual = mes_atual)
}


#' Expande a meta anual de inflação para frequência mensal
#'
#' A série 13521 do BCB fornece a meta em base anual. Esta função junta os
#' dados com o calendário mensal do IPCA pelo ano, de modo que cada mês
#' receba a meta vigente no seu ano calendário. Meses de anos sem meta
#' cadastrada recebem NA.
#'
#' Quando a série 13521 retorna múltiplos registros para o mesmo ano
#' (revisões intra-anuais), é mantido o valor mais recente.
#'
#' @param df_ipca Tibble com ao menos a coluna `data` (Date), conforme
#'   retornado por `coletar_ipca_mensal()`.
#' @param df_meta Tibble com colunas `data` (Date) e `meta_inflacao`,
#'   conforme retornado por `coletar_meta_inflacao()`.
#' @return Tibble com todas as colunas de `df_ipca` mais `meta_inflacao`.
preparar_meta_mensal <- function(df_ipca, df_meta) {
  meta_por_ano <- df_meta |>
    dplyr::arrange(data) |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::group_by(ano) |>
    dplyr::summarise(meta_inflacao = dplyr::last(meta_inflacao), .groups = "drop")

  df_ipca |>
    dplyr::mutate(ano = lubridate::year(data)) |>
    dplyr::left_join(meta_por_ano, by = "ano") |>
    dplyr::select(-ano)
}


# ══════════════════════════════════════════════════════════════════════════════
# Medidas de núcleo, difusão e ritmo
#
# Estas funções cobrem a lacuna analítica do relatório anterior: sem núcleo,
# sem difusão e sem leitura de ritmo de curto prazo, não se distingue choque
# pontual de pressão disseminada — que é a leitura relevante para política
# monetária e a que o público deste relatório espera encontrar.
# ══════════════════════════════════════════════════════════════════════════════


#' Variação anualizada da janela móvel de n meses
#'
#' Capitaliza a janela e eleva ao número de janelas do ano:
#'   ((prod(1 + x_i/100))^(12/n) - 1) * 100
#'
#' A leitura de 3 meses anualizada mostra o ritmo corrente da inflação sem a
#' inércia dos doze meses acumulados. É a medida que primeiro captura uma
#' inflexão.
#'
#' **Sem ajuste sazonal.** A série do IPCA publicada pelo IBGE é bruta; nenhum
#' ajuste é aplicado aqui, e o rótulo do gráfico não deve sugerir que há.
#' Compare sempre com o mesmo trimestre de anos anteriores (ver
#' `preparar_sazonal()`) antes de concluir que houve inflexão.
#'
#' @param df Tibble com colunas `data` (Date) e a coluna indicada em `coluna`.
#' @param n Tamanho da janela em meses. Padrão: 3.
#' @param coluna Nome da coluna de variação mensal. Padrão: "ipca_mm".
#' @param nome Nome da coluna de saída. Padrão: "anualizado_3m".
#' @return O mesmo tibble com a coluna anualizada adicionada.
calcular_anualizado <- function(df, n = 3L, coluna = "ipca_mm",
                                nome = paste0("anualizado_", n, "m")) {
  valores <- df[[coluna]]

  df |>
    dplyr::arrange(data) |>
    dplyr::mutate(
      !!nome := slider::slide_dbl(
        .x        = valores[order(df$data)],
        .f        = ~ (prod(1 + .x / 100)^(12 / n) - 1) * 100,
        .before   = n - 1L,
        .complete = TRUE
      )
    )
}


#' Média móvel de n meses
#'
#' Suaviza o ruído mensal sem a inércia do acumulado em doze meses.
#'
#' @param df Tibble com `data` e a coluna indicada.
#' @param n Tamanho da janela. Padrão: 3.
#' @param coluna Coluna a suavizar. Padrão: "ipca_mm".
#' @param nome Coluna de saída. Padrão: "media_movel_3m".
#' @return O tibble com a coluna de média móvel.
calcular_media_movel <- function(df, n = 3L, coluna = "ipca_mm",
                                 nome = paste0("media_movel_", n, "m")) {
  valores <- df[[coluna]]

  df |>
    dplyr::arrange(data) |>
    dplyr::mutate(
      !!nome := slider::slide_dbl(
        .x        = valores[order(df$data)],
        .f        = ~ mean(.x, na.rm = TRUE),
        .before   = n - 1L,
        .complete = TRUE
      )
    )
}


#' Índice de difusão: proporção de itens com variação positiva no mês
#'
#' Responde à pergunta que o índice cheio não responde: a inflação do mês veio
#' de poucos itens com alta forte, ou de muitos itens subindo pouco? Difusão
#' alta com índice baixo indica pressão disseminada — leitura mais preocupante
#' para política monetária do que um choque concentrado.
#'
#' Convenção: itens com variação exatamente zero contam como **não** positivos.
#' O limiar é parametrizável para replicar variantes que usam corte diferente
#' de zero.
#'
#' @param df_itens Tibble com `data` (Date), `item` (chr) e `variacao` (num).
#' @param limiar Variação mínima para o item contar como em alta. Padrão: 0.
#' @return Tibble com `data`, `n_itens`, `n_positivos` e `difusao` (0 a 100).
calcular_difusao <- function(df_itens, limiar = 0) {
  df_itens |>
    dplyr::filter(!is.na(variacao)) |>
    dplyr::group_by(data) |>
    dplyr::summarise(
      n_itens     = dplyr::n(),
      n_positivos = sum(variacao > limiar),
      difusao     = 100 * n_positivos / dplyr::n(),
      .groups     = "drop"
    ) |>
    dplyr::arrange(data)
}


#' Núcleo por médias aparadas, ponderado pelos pesos dos itens
#'
#' Ordena os itens do mês pela variação, acumula os pesos e descarta as caudas
#' que somam `corte`% do peso em cada extremo. O núcleo é a média ponderada dos
#' itens remanescentes, reescalada para somar 100% de peso.
#'
#' É uma implementação transparente e reproduzível a partir dos microdados do
#' SIDRA — **não** reproduz exatamente o IPCA-MS do Banco Central, que aplica
#' suavização prévia a itens de reajuste infrequente. Quando o núcleo oficial
#' estiver disponível via SGS, prefira-o; este serve de verificação
#' independente e continua funcionando se o SGS falhar.
#'
#' @param df_itens Tibble com `data`, `item`, `variacao` e `peso`.
#' @param corte Percentual de peso aparado em cada cauda. Padrão: 20.
#' @return Tibble com `data`, `nucleo_aparado` e `peso_utilizado`.
calcular_media_aparada <- function(df_itens, corte = 20) {
  stopifnot(corte >= 0, corte < 50)

  df_itens |>
    dplyr::filter(!is.na(variacao), !is.na(peso), peso > 0) |>
    dplyr::group_by(data) |>
    dplyr::arrange(variacao, .by_group = TRUE) |>
    dplyr::mutate(
      peso_relativo = 100 * peso / sum(peso),
      acumulado_ate = cumsum(peso_relativo),
      acumulado_ant = acumulado_ate - peso_relativo,
      # Peso do item que sobrevive ao corte: a fatia da sua faixa acumulada que
      # cai dentro do miolo [corte, 100 - corte]. Aparar item inteiro em vez de
      # fatia deslocaria o núcleo conforme a granularidade da cesta.
      peso_no_miolo = pmax(
        0,
        pmin(acumulado_ate, 100 - corte) - pmax(acumulado_ant, corte)
      )
    ) |>
    dplyr::summarise(
      peso_utilizado = sum(peso_no_miolo),
      nucleo_aparado = if (sum(peso_no_miolo) > 0) {
        sum(variacao * peso_no_miolo) / sum(peso_no_miolo)
      } else {
        NA_real_
      },
      .groups = "drop"
    ) |>
    dplyr::arrange(data)
}


#' Variação interanual por média de período
#'
#' Compara a média dos últimos `n` meses com a média dos `n` meses encerrados
#' um ano antes.
#'
#' Existe para corrigir um erro do resumo anterior: a variação em doze meses do
#' IBC-Br era calculada comparando o **nível do índice sem ajuste sazonal** de
#' um mês com o nível de um mês doze meses antes. Comparação ponto a ponto de
#' índice bruto carrega a sazonalidade dos dois meses e não mede o que o rótulo
#' "variação em 12 meses" promete.
#'
#' @param df Tibble com `data` (Date) e `valor` (num), ordenável por data.
#' @param data_ref Data de referência. Padrão: última data disponível.
#' @param n Número de meses da janela. Padrão: 12.
#' @return Variação percentual, ou NA se não houver janela completa dos dois lados.
variacao_interanual_media <- function(df, data_ref = NULL, n = 12L) {
  df <- df |>
    dplyr::filter(!is.na(valor)) |>
    dplyr::arrange(data)

  if (nrow(df) == 0L) {
    return(NA_real_)
  }
  data_ref <- if (is.null(data_ref)) max(df$data) else as.Date(data_ref)

  janela <- function(fim) {
    inicio <- lubridate::add_with_rollback(fim, months(-(n - 1L)))
    sub <- df[df$data >= inicio & df$data <= fim, ]
    if (nrow(sub) < n) NA_real_ else mean(sub$valor)
  }

  atual <- janela(data_ref)
  anterior <- janela(lubridate::add_with_rollback(data_ref, months(-12L)))

  if (is.na(atual) || is.na(anterior) || anterior == 0) {
    return(NA_real_)
  }
  (atual / anterior - 1) * 100
}


#' Variação acumulada no ano, por média de período
#'
#' Compara a média dos meses decorridos do ano calendário com a média do mesmo
#' conjunto de meses do ano anterior — a definição usada pelo IBGE e pelo BCB
#' para "acumulado no ano" de índices de volume como o IBC-Br.
#'
#' Substitui o cálculo anterior, que comparava o nível do índice contra o nível
#' de 31 de dezembro do ano anterior. Um único mês de dezembro, sem ajuste
#' sazonal, não é base válida para acumulado no ano.
#'
#' @param df Tibble com `data` (Date) e `valor` (num).
#' @param data_ref Data de referência. Padrão: última data disponível.
#' @return Variação percentual, ou NA quando não há meses correspondentes.
acumulado_no_ano_media <- function(df, data_ref = NULL) {
  df <- df |>
    dplyr::filter(!is.na(valor)) |>
    dplyr::arrange(data)

  if (nrow(df) == 0L) {
    return(NA_real_)
  }
  data_ref <- if (is.null(data_ref)) max(df$data) else as.Date(data_ref)

  ano <- lubridate::year(data_ref)
  meses <- lubridate::month(df$data[lubridate::year(df$data) == ano &
    df$data <= data_ref])
  if (length(meses) == 0L) {
    return(NA_real_)
  }

  atual <- mean(df$valor[lubridate::year(df$data) == ano &
    lubridate::month(df$data) %in% meses &
    df$data <= data_ref])

  anteriores <- df$valor[lubridate::year(df$data) == ano - 1L &
    lubridate::month(df$data) %in% meses]
  if (length(anteriores) < length(meses)) {
    return(NA_real_)
  }

  anterior <- mean(anteriores)
  if (is.na(atual) || is.na(anterior) || anterior == 0) {
    return(NA_real_)
  }
  (atual / anterior - 1) * 100
}


#' Situação do IPCA acumulado em 12 meses frente à meta contínua
#'
#' Desde janeiro de 2025 o Brasil opera sob **meta contínua**: a meta é
#' avaliada mês a mês sobre o IPCA acumulado em doze meses, e não apenas no
#' fechamento do ano calendário. O descumprimento é caracterizado quando o
#' acumulado fica fora do intervalo de tolerância por **seis meses
#' consecutivos**.
#'
#' @param df Tibble com `data` e `acum_12m`.
#' @param meta Centro da meta. Padrão: 3.
#' @param banda Tolerância em p.p. Padrão: 1,5.
#' @return Tibble com `data`, `acum_12m`, `desvio`, `fora_da_banda` e
#'   `meses_consecutivos_fora`.
avaliar_meta_continua <- function(df, meta = 3, banda = 1.5) {
  resultado <- df |>
    dplyr::filter(!is.na(acum_12m)) |>
    dplyr::arrange(data) |>
    dplyr::mutate(
      desvio        = acum_12m - meta,
      fora_da_banda = abs(desvio) > banda
    )

  # Contador corrido de meses consecutivos fora da banda.
  consecutivos <- integer(nrow(resultado))
  corrente <- 0L
  for (i in seq_len(nrow(resultado))) {
    corrente <- if (isTRUE(resultado$fora_da_banda[i])) corrente + 1L else 0L
    consecutivos[i] <- corrente
  }
  resultado$meses_consecutivos_fora <- consecutivos
  resultado
}
