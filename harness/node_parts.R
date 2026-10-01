# J's move between two runs whose node schedules nest, in two parts by birth band,
# as fractions of the coarser run's J: the field part, the change in net
# reproduction at the coarser run's births on its own weights, and the quadrature
# part, the rest. Run on three or more saved runs (harness/run_record.R), each
# nested in the next, it prints each move and the ratio of successive moves in J,
# which is 4 when the error falls as the spacing squared.
#
#   Rscript harness/node_parts.R coarse.rds finer.rds [finest.rds ...]

# J is the sum over nodes of establishment weight times net reproduction ratio,
# up to a constant factor.
nodes_of <- function(x) {
  n <- x$stand$nodes; m <- min(length(n$establishment), length(n$nrr))
  data.frame(birth = n$birth[1:m], w = n$establishment[1:m], nrr = n$nrr[1:m])
}

node_parts <- function(a, b, bands) {
  m <- match(round(a$birth, 10), round(b$birth, 10))
  stopifnot(!anyNA(m))
  J <- sum(a$w * a$nrr)
  field <- tapply(a$w * (b$nrr[m] - a$nrr), cut(a$birth, bands, right = FALSE), sum) / J
  quad <- (tapply(b$w * b$nrr, cut(b$birth, bands, right = FALSE), sum) -
             tapply(a$w * b$nrr[m], cut(a$birth, bands, right = FALSE), sum)) / J
  list(field = field, quad = quad)
}

if (sys.nframe() == 0) {
  files <- commandArgs(TRUE)
  runs <- lapply(files, readRDS)
  J <- vapply(runs, function(x) x$stand$J, 0)
  for (i in seq_along(runs)) cat(sprintf("%-28s %4d nodes  J %.8g\n", basename(files[i]), length(runs[[i]]$node_times), J[i]))
  bands <- c(-1, 1, 3, 10, 41)
  f <- function(x) paste(sprintf("%+.5f", x), collapse = " ")
  for (i in seq_len(length(runs) - 1)) {
    p <- node_parts(nodes_of(runs[[i]]), nodes_of(runs[[i + 1]]), bands)
    cat(sprintf("%s -> %s: net %+.5f | field %+.5f (b < 1, 1-3, 3-10, later: %s) | quadrature %+.5f (%s)\n",
                basename(files[i]), basename(files[i + 1]), sum(p$field) + sum(p$quad),
                sum(p$field), f(p$field), sum(p$quad), f(p$quad)))
  }
  for (i in seq_len(length(runs) - 2))
    cat(sprintf("ratio of successive moves in J: %.3g\n", (J[i] - J[i + 1]) / (J[i + 1] - J[i + 2])))
}
