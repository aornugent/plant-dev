# The thinning's gates (prereg.txt, "The thinning"), from thin.R's runs.
#   DEV=... Rscript docs/measurements/node-rule/thin_read.R    # from plant-dev's root
source("docs/measurements/pathfinders/invader-thinning/emulate.R")
D <- Sys.getenv("DEV")
O <- file.path(D, "node_rule", "thin")
eps <- read.csv("docs/measurements/eps.csv")
eps_of <- function(trait) {
  e <- eps$eps[eps$role == "invader" & eps$trait == trait & eps$unit != "curvature in lma"]
  max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE)
}
verdict <- function(ok) if (isTRUE(ok)) "holds" else "FAILS"
rel <- function(a, b) max(abs(a - b) / pmax(abs(b), 1e-300))
records <- c(ld = "long-drought", epi = "episodic")
for (key in names(records)) {
  tag <- records[[key]]
  f <- file.path(O, sprintf("thin_%s.rds", key))
  if (!file.exists(f)) { cat("==", tag, "not run yet\n"); next }
  x <- readRDS(f)
  cat(sprintf("== %s: the stand's J %.10g\n", tag, x$stand$J))
  full <- x$cases[["stand=1"]]$full
  cat(sprintf("   the diagonal: the full walk's J' %s J  %s\n",
              if (identical(full$J, x$stand$J)) "=" else "!=", verdict(identical(full$J, x$stand$J))))
  for (rule in x$rules) {
    rows <- list()
    for (k in names(x$cases)) {
      a <- x$cases[[k]]$full; b <- x$cases[[k]][[rule]]
      if (is.null(b) || !is.null(b$error) || is.null(b$elasticity) || is.null(a$elasticity)) {
        rows[[k]] <- data.frame(invader = k, P1 = FALSE, dlnJ = NA, worst = NA, trait = NA,
                                saved = NA, failed = TRUE)
        next
      }
      kp <- b$keep
      P1 <- identical(b$nodes$nrr, a$nodes$nrr[kp]) &&
        identical(b$nodes$splits[seq_along(kp)], a$nodes$splits[kp]) &&
        rel(b$J, J_of(a$nodes, kp)) <= 1e-12
      tr <- sub("^1\\.", "", names(a$elasticity))
      e <- vapply(tr, eps_of, 0)
      mv <- abs(unname(b$elasticity) - unname(a$elasticity)) / e
      rows[[k]] <- data.frame(invader = k, P1 = P1,
        dlnJ = abs(log(b$J) - log(a$J)) / eps_of("ln J"), worst = max(mv),
        trait = tr[which.max(mv)],
        saved = 1 - (b$walk_secs + b$sweep_secs) / (a$walk_secs + a$sweep_secs), failed = FALSE)
    }
    d <- do.call(rbind, rows)
    off <- d$invader != "stand=1"
    cat(sprintf("   rule %-11s (i) %d of %d exact  %s; (ii) ln J' largest %.3f eps  %s; (iii) elasticities largest %.3f eps (%s)  %s; (iv) median saved %.1f%%  %s\n",
                rule, sum(d$P1), nrow(d), verdict(all(d$P1)),
                max(d$dlnJ[off]), verdict(all(d$dlnJ[off] < 1 / 3)),
                max(d$worst[off]), d$trait[off][which.max(d$worst[off])],
                verdict(all(d$worst[off] < 1 / 3)), 100 * median(d$saved[off]),
                verdict(median(d$saved[off]) >= 0.3)))
    s <- d[!off, ]
    cat(sprintf("      the diagonal thinned: ln J' %.3f eps, elasticities %.3f eps (%s), saved %.1f%%\n",
                s$dlnJ, s$worst, s$trait, 100 * s$saved))
  }
  if (!is.null(x$fd)) for (i in seq_len(nrow(x$fd))) {
    r <- x$fd[i, ]
    cat(sprintf("   the thinned sweep against a difference, %s %s: %.6f / %.6f (%.1e)\n",
                r$rule, r$trait, r$swept, r$difference, r$swept - r$difference))
  }
}
