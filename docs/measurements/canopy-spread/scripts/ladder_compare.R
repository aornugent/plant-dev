# Every quantity (ln J and each elasticity, both roles, in units of its eps) on
# nested ladders of run_record.R runs: the ratio of successive moves, each rung's
# error against a reference, and the companion's estimate (a third of the move
# from the coarser rung) over the error. As harness/error_structure.R, a ratio is
# counted where the finer move is at least three times the tolerance nudge.
#
#   Rscript ladder_compare.R REF_COARSE REF_FINE NUDGE_BASE NUDGE name1=a,b,c [name2=a,b,c ...]
# The reference is REF_FINE + (REF_FINE - REF_COARSE) / 3.
wt <- "/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba"
eps <- read.csv(file.path(wt, "docs/measurements/eps.csv"))
eps <- eps[eps$unit != "curvature in lma", ]
main <- c("ln J", "lma", "rho", "hmat", "stem_P50", "a_dG2")
small <- c("a_st3", "a_d0", "omega", "a_l1")
asked <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho", "recruitment_decay", "a_y", "a_bio",
           "a_f1", "a_l2", "theta", "jmax_25")
eps_of <- function(role, trait) { e <- eps$eps[eps$role == role & eps$trait == trait]; if (length(e)) e[1] else NA }
quantities <- function(x) {
  out <- c()
  for (role in c("stand", "invader")) {
    if (is.null(x[[role]]$elasticity)) next
    r <- if (role == "stand") "resident" else "invader"
    tr <- c("ln J", sub("^1[.]", "", names(x[[role]]$elasticity)))
    v <- c(log(x[[role]]$J), unname(x[[role]]$elasticity)) / vapply(tr, function(t) eps_of(r, t), 0)
    names(v) <- paste(r, tr)
    out <- c(out, v)
  }
  out[is.finite(out)]
}
args <- commandArgs(TRUE)
rc <- quantities(readRDS(args[1])); rf <- quantities(readRDS(args[2]))
ref <- rf + (rf - rc) / 3
nb <- quantities(readRDS(args[3])); nn <- quantities(readRDS(args[4]))
ladders <- lapply(args[-(1:4)], function(a) {
  kv <- strsplit(a, "=")[[1]]; list(name = kv[1], files = strsplit(kv[2], ",")[[1]])
})
trait <- function(k) sub("^(resident|invader) ", "", k)
role <- function(k) sub(" .*", "", k)
group <- function(k) paste(role(k), ifelse(trait(k) %in% main, "main", ifelse(trait(k) %in% small, "small", "other")))
res <- list()
for (l in ladders) {
  q <- lapply(l$files, function(f) quantities(readRDS(f)))
  k <- Reduce(intersect, c(lapply(q, names), list(names(ref), names(nb), names(nn))))
  nudge <- abs(nn[k] - nb[k])
  ratio <- (q[[1]][k] - q[[2]][k]) / (q[[2]][k] - q[[3]][k])
  resolved <- abs(q[[2]][k] - q[[3]][k]) >= 3 * nudge
  err <- lapply(q, function(v) v[k] - ref[k])
  comp2 <- abs(q[[1]][k] - q[[2]][k]) / 3 / abs(err[[2]])
  comp3 <- abs(q[[2]][k] - q[[3]][k]) / 3 / abs(err[[3]])
  res[[l$name]] <- data.frame(q = k, group = group(k), ratio = ratio, resolved = resolved,
                              e1 = err[[1]], e2 = err[[2]], e3 = err[[3]], comp2 = comp2, comp3 = comp3,
                              stringsAsFactors = FALSE)
}
cat("== the asked quantities: ratio of successive moves (* where resolved), errors at the three rungs (eps), companion over error at rungs 2 and 3\n")
for (nm in names(res)) {
  d <- res[[nm]]; d <- d[trait(d$q) %in% asked & !(role(d$q) == "resident" & !(trait(d$q) %in% c("ln J", "lma"))), ]
  d <- d[order(role(d$q), match(trait(d$q), asked)), ]
  cat("\n--", nm, "\n")
  print(data.frame(q = d$q, ratio = sprintf("%7.2f%s", d$ratio, ifelse(d$resolved, "*", " ")),
                   err = sprintf("%+.3f %+.3f %+.3f", d$e1, d$e2, d$e3),
                   companion = sprintf("%.2f %.2f", d$comp2, d$comp3)), row.names = FALSE)
}
cat("\n== by group, outside the small four: resolved quantities, their median ratio, below 0, in 2.5-6;\n")
cat("   median |error| at each rung (eps); median companion over error where the error exceeds 0.05 eps\n")
for (nm in names(res)) {
  d <- res[[nm]]; d <- d[!grepl("small", d$group), ]
  g <- split(d, d$group)
  tab <- t(vapply(g, function(x) {
    r <- x$ratio[x$resolved]
    c(n = nrow(x), resolved = length(r), median_ratio = median(r), below0 = sum(r < 0), in_2.5_6 = sum(r >= 2.5 & r < 6),
      err1 = median(abs(x$e1)), err2 = median(abs(x$e2)), err3 = median(abs(x$e3)),
      comp2 = median(x$comp2[abs(x$e2) > 0.05]), comp3 = median(x$comp3[abs(x$e3) > 0.05]))
  }, numeric(10)))
  cat("\n--", nm, "\n"); print(round(tab, 3))
}
