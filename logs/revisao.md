ok

Ciclo 2 de 2, referência 2026-11-09. Notas não bloqueantes:

- A frase calculada por `cambio_saltos_txt` traz só a alta de 9,19% em 26/10/2026. A queda de 4,55% em 05/10/2026 não entra, e isso está certo: a janela vai da base do mês (09/10/2026, R$ 4,99) até hoje, e 05/10 é anterior à base. A sugestão do ciclo 1, que citava as duas variações, estava errada neste ponto. A frase final é: "O intervalo vai de R$ 4,99 (09/10/2026) a R$ 5,51 (09/11/2026). Ele inclui uma alta de 9,19% em 26/10/2026, de modo que a variação mensal concentra um salto pontual e deve ser lida com cautela; ..."
- O trecho "os acumulados do ano e em doze meses são menos sensíveis a eles" é fixo no código e não é calculado. Vale nesta semana (+0,22% e +2,95%), mas pode não valer em outra. Convém condicioná-lo aos dados ou retirá-lo.
- `cambio_saltos_txt` usa `seq(by = "-1 month")` e `max(s$data)`, enquanto `gerar_resumo.R` usa `%m-% months(1)` e a data de referência. Hoje coincidem (base 09/10). Em fim de mês (dia 29 a 31) a base pode divergir da do resumo.csv.
- `_quarto.yml` lista só `relatorio_ipca.qmd` em `project: render`. Confirmar que o workflow renderiza `boletim.qmd` explicitamente.
