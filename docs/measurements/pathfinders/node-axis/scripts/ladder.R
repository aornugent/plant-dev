# The node axis's ladders on one record: for each arm (lumped uniform L, graded B,
# spread uniform D, spread graded B+D), each finished rung's quantities in eps (ln J
# and both roles' elasticities; every eps but ln J's floored at 0.01), the ratio of
# successive moves on every rung triple, the companions against the arm's finest
# extrapolation, each rung's and each lower two-rung extrapolation's distance from
# it, the arms' agreement, and the rules' answers against a common reference.
#   Rscript ladder.R long-wet|long-drought
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
N <- file.path(D, "pf_nodes")
rec <- commandArgs(TRUE)[1]
short <- c("long-wet" = "wet", "long-drought" = "ld")[[rec]]

eps <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps <- eps[eps$unit != "curvature in lma", ]
eps_of <- function(role, trait) {
  e <- eps$eps[eps$role == role & eps$trait == trait]
  if (!length(e) || is.na(e[1])) return(NA_real_)
  if (trait == "ln J") e[1] else max(e[1], 0.01)
}
structural <- c("S_D", "a_f3")
quantities <- function(x) {
  out <- c()
  for (role in c("stand", "invader")) {
    r <- if (role == "stand") "resident" else "invader"
    tr <- c("ln J", sub("^1[.]", "", names(x[[role]]$elasticity)))
    v <- c(log(x[[role]]$J), unname(x[[role]]$elasticity)) /
      vapply(tr, function(t) eps_of(r, t), 0)
    names(v) <- paste(r, tr)
    out <- c(out, v[!tr %in% structural])
  }
  out[is.finite(out)]
}
finished <- function(x) !is.null(x$finished) && !is.null(x$stand$elasticity) &&
  !is.null(x$invader$elasticity)
# Members alive at each accepted step's start.
rows_of <- function(x) {
  b <- sort(x$stand$nodes$birth)
  sum(findInterval(x$stand$times[-1] - x$stand$sizes[-1], b))
}
cpu_of <- function(x) sum(vapply(x$phases, function(p) if (length(p$cpu)) p$cpu else NA_real_, 0))

run_file <- function(name) {
  if (name == sprintf("%s_L_u108", short))
    return(file.path(D, sprintf("phase1c/combined/full/bnd_%s.rds", short)))
  file.path(N, "runs", paste0(name, ".rds"))
}
arms <- list(
  L = c("L_u54", "L_u108", "L_u215"),
  B = c("B_G1", "B_G2", "B_G3"),
  D = c("D_u54", "D_u108", "D_u215", "D_u429"),
  "B+D" = c("BD_G1", "BD_G2", "BD_G3"))

# The +-5% tolerance nudge at u108 on long drought, each quantity's larger move: a
# move resolves when it is at least three times this.
qb <- quantities(readRDS(file.path(D, "phase1c/combined/full/bnd_ld.rds")))
qn <- lapply(c("2.85e-5", "3.15e-5"), function(s)
  quantities(readRDS(file.path(D, sprintf("phase1c/combined/full/bnd_ld_%s.rds", s)))))
nk <- Reduce(intersect, list(names(qb), names(qn[[1]]), names(qn[[2]])))
nudge <- pmax(abs(qn[[1]][nk] - qb[nk]), abs(qn[[2]][nk] - qb[nk]))

main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")
group_of <- function(q) {
  role <- sub(" .*", "", q); tr <- sub("^(resident|invader) ", "", q)
  paste(role, ifelse(tr %in% main, "main", "other"))
}
groups <- c("resident main", "resident other", "invader main", "invader other")
med <- function(v) if (length(v)) sprintf("%.2f", median(v)) else "-"
spread <- function(d) sprintf("median %.3f, largest %.3f (%s)", median(abs(d)), max(abs(d)),
                              names(d)[which.max(abs(d))])

cat(sprintf("== %s: the node axis's ladders (bounded Cash-Karp, 3e-5), in eps\n", rec))
refs <- list(); qs_all <- list(); rows_all <- list()
for (arm in names(arms)) {
  runs <- arms[[arm]]
  have <- runs[file.exists(vapply(paste(short, runs, sep = "_"), run_file, ""))]
  if (!length(have)) next
  xs <- lapply(have, function(r) readRDS(run_file(paste(short, r, sep = "_"))))
  ok <- vapply(xs, finished, TRUE)
  cat(sprintf("\n-- %s: %s\n", arm, paste(sprintf("%s (%d nodes, %.0f rows, %.0f cpu s%s)", have,
      vapply(xs, function(x) length(x$stand$nodes$birth), 0), vapply(xs, rows_of, 0),
      vapply(xs, cpu_of, 0), ifelse(ok, "", ", unfinished")), collapse = "; ")))
  have <- have[ok]; xs <- xs[ok]
  m <- length(have)
  if (!m) next
  qs <- lapply(xs, quantities); names(qs) <- have
  qs_all[[arm]] <- qs; rows_all[[arm]] <- setNames(vapply(xs, rows_of, 0), have)
  if (m < 2) next
  k <- Reduce(intersect, lapply(qs, names))
  q <- lapply(qs, function(v) v[k])
  ref <- q[[m]] + (q[[m]] - q[[m - 1]]) / 3
  refs[[arm]] <- ref
  for (i in seq_len(m)) cat(sprintf("   %-7s from the finest extrapolation: %s\n", have[i], spread(q[[i]] - ref)))
  for (i in seq_len(m - 2)) {
    e <- q[[i + 1]] + (q[[i + 1]] - q[[i]]) / 3
    cat(sprintf("   %s+%s extrapolated, from it: %s\n", have[i], have[i + 1], spread(e - ref)))
  }
  kk <- intersect(k, nk); g <- group_of(kk)
  # Companions at the middle rungs: the estimate (Q_n - Q_2n)/3 over the error Q_2n - ref,
  # on quantities whose error resolves.
  for (i in seq_len(m - 2)) {
    est <- ((q[[i]] - q[[i + 1]]) / 3)[kk]; err <- (q[[i + 1]] - ref)[kk]
    res <- abs(err) >= 3 * nudge[kk]
    cat(sprintf("   companion at %s: estimate/error median %s over %d resolved of %d; %s\n",
                have[i + 1], med((est / err)[res]), sum(res), length(kk),
                paste(sprintf("%s %s (%d)", groups, vapply(groups, function(z) med((est / err)[res & g == z]), ""),
                              vapply(groups, function(z) sum(res & g == z), 0L)), collapse = ", ")))
  }
  for (i in seq_len(m - 2)) {
    d1 <- (q[[i]] - q[[i + 1]])[kk]; d2 <- (q[[i + 1]] - q[[i + 2]])[kk]
    res <- abs(d2) >= 3 * nudge[kk]
    r <- (d1 / d2)[res]; gr <- g[res]
    on <- function(v) length(v) && median(v) >= 3 && median(v) <= 5.3 && mean(v < 0) < 0.1
    cat(sprintf("   ratio %s/%s/%s: resolved %d of %d, median %s, negative %d\n     %s\n",
                have[i], have[i + 1], have[i + 2], sum(res), length(kk), med(r), sum(r < 0),
                paste(sprintf("%s %s (%d%s)", groups, vapply(groups, function(z) med(r[gr == z]), ""),
                              vapply(groups, function(z) sum(gr == z), 0L),
                              ifelse(vapply(groups, function(z) on(r[gr == z]), TRUE), ", square law", "")),
                      collapse = "; ")))
  }
}

if (length(refs) >= 2) {
  cat("\n-- the arms' finest extrapolations against one another\n")
  nm <- names(refs)
  for (i in seq_along(nm)) for (j in seq_along(nm)) if (i < j) {
    k <- intersect(names(refs[[i]]), names(refs[[j]]))
    cat(sprintf("   %s vs %s: %s\n", nm[i], nm[j], spread(refs[[i]][k] - refs[[j]][k])))
  }
}

# Each rule's reported answer against the common reference, the median of the finest
# extrapolations of B, D and B+D (L's coarse ladder left out), with its error estimate
# |Q_n - Q_2n| / 3 and the share of quantities it covers.
arms_ref <- intersect(c("B", "D", "B+D"), names(refs))
if (length(arms_ref) >= 2) {
  k <- Reduce(intersect, lapply(refs[arms_ref], names))
  ref <- apply(do.call(cbind, lapply(refs[arms_ref], function(r) r[k])), 1, median)
  cat(sprintf("\n-- the rules' answers against the median of %s's finest extrapolations\n",
              paste(arms_ref, collapse = ", ")))
  for (a in names(refs)) {
    kk <- intersect(names(refs[[a]]), k)
    cat(sprintf("   %-26s %8s rows: %s\n", paste(a, "finest extrapolation"), "", spread(refs[[a]][kk] - ref[kk])))
  }
  answer <- function(arm, a, b, extrapolate) {
    qs <- qs_all[[arm]]
    if (is.null(qs[[a]]) || is.null(qs[[b]])) return(invisible())
    k <- Reduce(intersect, list(names(ref), names(qs[[a]]), names(qs[[b]])))
    v <- if (extrapolate) qs[[b]][k] + (qs[[b]][k] - qs[[a]][k]) / 3 else qs[[b]][k]
    est <- abs(qs[[a]][k] - qs[[b]][k]) / 3
    err <- v - ref[k]
    cat(sprintf("   %-26s %8.0f rows: %s; estimate covers %.0f%%\n",
                sprintf("%s %s%s%s", arm, a, if (extrapolate) "+" else " companion of ", b),
                rows_all[[arm]][[a]] + rows_all[[arm]][[b]], spread(err), 100 * mean(abs(err) <= est)))
  }
  single <- function(arm, a) {
    v <- qs_all[[arm]][[a]]
    if (is.null(v)) return(invisible())
    k <- intersect(names(ref), names(v))
    cat(sprintf("   %-26s %8.0f rows: %s; no estimate\n", paste(arm, a, "alone"),
                rows_all[[arm]][[a]], spread(v[k] - ref[k])))
  }
  single("B+D", "BD_G1"); single("D", "D_u108"); single("L", "L_u108")
  answer("B", "B_G1", "B_G2", FALSE); answer("B", "B_G1", "B_G2", TRUE)
  answer("D", "D_u108", "D_u215", TRUE); answer("D", "D_u215", "D_u429", TRUE)
  answer("B+D", "BD_G1", "BD_G2", FALSE); answer("B+D", "BD_G2", "BD_G3", FALSE)
  answer("L", "L_u108", "L_u215", TRUE)
}
