library(testthat)

rprojroot_raiz <- function() {
  # Sobe até encontrar a raiz do projeto (onde fica _quarto.yml).
  caminho <- normalizePath(".")
  while (!file.exists(file.path(caminho, "_quarto.yml")) && dirname(caminho) != caminho) {
    caminho <- dirname(caminho)
  }
  caminho
}

test_dir("testthat", env = environment())
