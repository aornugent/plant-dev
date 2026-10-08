# The shared schedule from the pilot (prereg.txt), against thin.R's full walks.
#   DEV=... Rscript docs/measurements/node-rule/pilot_thin_read.R    # from plant-dev's root
source("docs/measurements/pathfinders/invader-thinning/emulate.R")
D <- Sys.getenv("DEV")
O <- file.path(D, "node_rule", "thin")
eps <- read.csv("docs/measurements/eps.csv")
eps_of <- function(trait) {
  e <- eps$eps[eps$role == "invader" & eps$trait == trait & eps$unit != "curvature in lma"]
  max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE)
}
verdict <- function(ok) if (isTRUE(ok)) "holds" else "FAILS"
for (key in c("ld", "epi")) {
  f <- file.path(O, sprintf("pthin_%s.rds", key))
  if (!file.exists(f)) { cat("==", key, "not run yet\n"); next }
  x <- readRDS(f); full <- readRDS(file.path(O, sprintf("thin_%s.rds", key)))
  u <- full$cases[["stand=1"]][["union 0.03"]]$keep
  saved <- function(kp) 1 - rows_of(x$stand_times, x$node_times[kp]) / rows_of(x$stand_times, x$node_times)
  cat(sprintf("== %s: %d of 108 kept (the nine walks' union %d, %d shared); rows saved %.1f%% (the union's %.1f%%)\n",
              x$regime, length(x$keep), length(u), length(intersect(x$keep, u)),
              100 * saved(x$keep), 100 * saved(u)))
  d <- do.call(rbind, lapply(names(full$cases), function(k) {
    a <- full$cases[[k]]$full; b <- x$cases[[k]]
    if (is.null(b) || !is.null(b$error)) return(data.frame(invader = k, dlnJ = NA, worst = NA, trait = NA, traits = NA))
    tr <- sub("^1\\.", "", names(a$elasticity))
    mv <- abs(unname(b$elasticity) - unname(a$elasticity)) / vapply(tr, eps_of, 0)
    trait_mv <- mv[tr != "recruitment_decay"]
    data.frame(invader = k, dlnJ = abs(log(b$J) - log(a$J)) / eps_of("ln J"), worst = max(mv),
               trait = tr[which.max(mv)], traits = max(trait_mv))
  }))
  print(d, row.names = FALSE, digits = 3)
  off <- d$invader != "stand=1"
  cat(sprintf("   never fails %s; (ii) ln J' largest %.3f eps %s; (iii) elasticities largest %.3f eps (%s %s) %s\n",
              verdict(!anyNA(d$worst)), max(d$dlnJ[off]), verdict(all(d$dlnJ[off] < 1 / 3)),
              max(d$worst[off]), d$invader[off][which.max(d$worst[off])],
              d$trait[off][which.max(d$worst[off])], verdict(all(d$worst[off] < 1 / 3))))
  cat(sprintf("   without recruitment_decay, a nuisance parameter: elasticities largest %.3f eps (%s)\n",
              max(d$traits[off]), d$invader[off][which.max(d$traits[off])]))
  for (tr in names(x$difference)) {
    ref <- unname(full$cases[["stand=1"]]$full$elasticity[paste0("1.", tr)])
    m <- abs(x$difference[[tr]] - ref) / eps_of(tr)
    cat(sprintf("   (v) the selection gradient in %s by differences on the schedule %.5f, the full sweep's %.5f: %.3f eps %s\n",
                tr, x$difference[[tr]], ref, m, verdict(m < 1 / 3)))
  }
}
