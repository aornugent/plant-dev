# Q2: thinning after b = 10 (every fourth node kept, 48 nodes) against the u108 rung,
# lumped (L) and spread (D), long-wet. J's move split by node_parts into the field part
# (the change in net reproduction at the thinned run's births, on its own weights) and
# the quadrature part, by birth band; and every quantity's move in eps, both roles.
#   Rscript q2_thin.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
N <- file.path(D, "pf_nodes")
.libPaths(c(file.path(N, "lib"), .libPaths()))
suppressMessages(library(plant))
source(file.path(N, "harness", "node_parts.R"))
eps <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps <- eps[eps$unit != "curvature in lma", ]
eps_of <- function(role, trait) {
  e <- eps$eps[eps$role == role & eps$trait == trait]
  if (!length(e) || is.na(e[1])) return(NA_real_)
  if (trait == "ln J") e[1] else max(e[1], 0.01)
}
quantities <- function(x) {
  out <- c()
  for (role in c("stand", "invader")) {
    r <- if (role == "stand") "resident" else "invader"
    tr <- c("ln J", sub("^1[.]", "", names(x[[role]]$elasticity)))
    v <- c(log(x[[role]]$J), unname(x[[role]]$elasticity)) / vapply(tr, function(t) eps_of(r, t), 0)
    names(v) <- paste(r, tr)
    out <- c(out, v[!tr %in% c("S_D", "a_f3")])
  }
  out[is.finite(out)]
}
pairs <- list(L = c(file.path(N, "runs/wet_L_u108_thin10.rds"), file.path(D, "phase1c/combined/full/bnd_wet.rds")),
              D = c(file.path(N, "runs/wet_D_u108_thin10.rds"), file.path(N, "runs/wet_D_u108.rds")))
bands <- c(0, 10, 20, 40, Inf)
for (arm in names(pairs)) {
  if (!all(file.exists(pairs[[arm]]))) { cat(arm, ": not run yet\n"); next }
  xa <- readRDS(pairs[[arm]][1]); xb <- readRDS(pairs[[arm]][2])
  p <- node_parts(nodes_of(xa), nodes_of(xb), bands)
  cat(sprintf("== %s: thin10 (%d nodes) -> u108 (%d nodes); J %.6f -> %.6f, ln J moves %.3f eps\n", arm,
              length(xa$stand$nodes$birth), length(xb$stand$nodes$birth), xa$stand$J, xb$stand$J,
              log(xb$stand$J / xa$stand$J) / eps_of("resident", "ln J")))
  cat("   J's move by birth band, fractions of thin10's J: field", paste(sprintf("%s %+.2e", names(p$field), p$field), collapse = ", "),
      "\n   quadrature", paste(sprintf("%s %+.2e", names(p$quad), p$quad), collapse = ", "), "\n")
  if (!is.null(xa$invader$elasticity) && !is.null(xb$invader$elasticity)) {
    qa <- quantities(xa); qb <- quantities(xb); k <- intersect(names(qa), names(qb))
    d <- qb[k] - qa[k]
    cat(sprintf("   quantities moving over eps/3: %d of %d; largest %.3f eps (%s); median %.3f\n",
                sum(abs(d) > 1 / 3), length(k), max(abs(d)), names(d)[which.max(abs(d))], median(abs(d))))
  }
}
