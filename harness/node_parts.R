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

# The same move placed in birth date without a band's edge cutting a hat, where
# each of the coarser run's panels holds at most one of the finer run's nodes:
# per coarser node, the field part and the change in its establishment weight
# (the finer run's creation on the coarser hats), and per coarser panel, the
# interpolation part. The three sum to the move in J.
panel_moves <- function(a, b) {
  m <- match(round(a$birth, 10), round(b$birth, 10))
  stopifnot(!anyNA(m))
  extra <- setdiff(seq_len(nrow(b)), m)
  j <- findInterval(b$birth[extra], a$birth)
  stopifnot(!anyDuplicated(j), all(j >= 1 & j < nrow(a)))
  lambda <- (b$birth[extra] - a$birth[j]) / (a$birth[j + 1] - a$birth[j])
  w <- b$w[m]
  w[j] <- w[j] + (1 - lambda) * b$w[extra]
  w[j + 1] <- w[j + 1] + lambda * b$w[extra]
  interpolation <- numeric(nrow(a))
  interpolation[j] <- b$w[extra] *
    (b$nrr[extra] - (1 - lambda) * b$nrr[m[j]] - lambda * b$nrr[m[j + 1]])
  data.frame(birth = a$birth, field = a$w * (b$nrr[m] - a$nrr),
             establishment = (w - a$w) * b$nrr[m], interpolation = interpolation)
}

# The invader's lma elasticity's move between two harness/invader_nodes.R runs,
# placed as panel_moves() places J's: each part's central difference over the
# two perturbations, over the coarser run's invader offspring.
elasticity_moves <- function(xa, xb) {
  stopifnot(xa$u == xb$u)
  at <- function(x, s) nodes_of(list(stand = list(nodes = x$invader[[s]])))
  part <- function(s) {
    a <- at(xa, s)
    panel_moves(a, at(xb, s))[, -1] / sum(a$w * a$nrr)
  }
  cbind(birth = at(xa, "plus")$birth, (part("plus") - part("minus")) / (2 * xa$u))
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
