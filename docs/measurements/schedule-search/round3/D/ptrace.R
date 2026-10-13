# Parse PARAMS lines (step k, t, h, trait-adjoint row after the step) into a matrix.
read_params <- function(f, names) {
  l <- grep("^PARAMS ", readLines(f), value = TRUE)
  m <- do.call(rbind, lapply(strsplit(l, " "), function(x) as.numeric(x[-1])))
  d <- data.frame(k = m[, 1], t = m[, 2], h = m[, 3])
  g <- m[, -(1:3), drop = FALSE]; colnames(g) <- names
  list(d = d, g = g)
}
