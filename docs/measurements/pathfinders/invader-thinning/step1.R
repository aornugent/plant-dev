# Step 1: each rule's exact emulated ln J' error (in eps, eps = 0.025) and the
# invader's walk and sweep rows saved, for the stand's invader and eight more on
# each record. Rule (a) drops members past the cumulative share 1 - delta; rule
# (b) spaces them by the root law, per invader; "union" is rule (b) on the
# largest share over the nine invaders, and "diag" rule (b) on the stand's own
# shares, which the forward run gives; each one schedule per record.
#
#   Rscript step1.R
source("emulate.R")
EPS <- 0.025
recs <- c("long-drought", "episodic", "long-wet")
cs_b <- c(1, 0.3, 0.1, 0.03, 0.01, 0.001)

union_shares <- function(walks) {
  s <- sapply(walks, function(w) shares_of(w$nodes))
  list(birth = walks[[1]]$nodes$birth, s = apply(s, 1, max))
}
rule_b_on <- function(birth, s, c) rule_b(list(birth = birth, w = c(s, 0), nrr = rep(1, length(s)),
                                               pd = 1, S_D = 1, br = 1), c)
res <- list()
for (r in recs) {
  f <- sprintf("runs/walks_%s.rds", r)
  if (!file.exists(f)) next
  x <- readRDS(f); st <- x$stand$times
  ok <- vapply(x$walks, function(w) !is.null(w$J), TRUE)
  walks <- x$walks[ok]
  cat(sprintf("\n== %s: J %.8g, %d steps, walks %s%s\n", r, x$stand$J, length(st),
              paste(names(walks), collapse = " "),
              if (any(!ok)) paste(" | failed:", paste(names(x$walks)[!ok], collapse = " ")) else ""))
  sd <- x$stand$nodes; sw <- walks[["stand=1"]]$nodes
  if (!is.null(sw)) cat(sprintf("stand's invader per-node data identical to the stand's: fecundity %s, E %s, M %s, w %s\n",
                                identical(sd$nrr, sw$nrr), identical(sd$E, sw$E), identical(sd$M, sw$M), identical(sd$w, sw$w)))
  u <- union_shares(walks)
  for (k in names(walks)) {
    nd <- walks[[k]]$nodes; n <- length(nd$birth)
    J0 <- J_of(nd, 1:n); r0 <- rows_of(st, nd$birth)
    rules <- list("a 1e-3" = rule_a(nd, 1e-3), "a 1e-4" = rule_a(nd, 1e-4))
    for (cc in cs_b) rules[[sprintf("b %g", cc)]] <- rule_b(nd, cc)
    for (cc in cs_b) rules[[sprintf("union %g", cc)]] <- rule_b_on(u$birth, u$s, cc)
    for (cc in cs_b) rules[[sprintf("diag %g", cc)]] <- rule_b_on(u$birth, shares_of(sd), cc)
    for (rn in names(rules)) {
      kp <- rules[[rn]]
      d <- log(J_of(nd, kp) / J0)
      res[[length(res) + 1]] <- data.frame(record = r, invader = k, rule = rn, keep = length(kp),
                                           last = nd$birth[max(kp)], dlnJ = d, eps = abs(d) / EPS,
                                           saved = 1 - rows_of(st, nd$birth[kp]) / r0,
                                           emul_check = J0 / walks[[k]]$J - 1)
    }
  }
}
res <- do.call(rbind, res)
saveRDS(res, "step1.rds")
cat(sprintf("\nemulation of the full schedule against each walk's J': largest relative difference %.2e\n",
            max(abs(res$emul_check))))
for (rn in unique(res$rule)) {
  s <- res[res$rule == rn, ]
  cat(sprintf("%-11s %2d cases: ln J' error median %.3f eps, largest %.3f eps (%s %s); over eps/3: %d | rows saved median %.1f%%, range %.1f-%.1f%% | kept %d-%d\n",
              rn, nrow(s), median(s$eps), max(s$eps), s$record[which.max(s$eps)], s$invader[which.max(s$eps)],
              sum(s$eps >= 1 / 3), 100 * median(s$saved), 100 * min(s$saved), 100 * max(s$saved), min(s$keep), max(s$keep)))
}
cat("\nper case (eps | rows saved):\n")
w <- reshape(res[, c("record", "invader", "rule", "eps", "saved")], idvar = c("record", "invader"),
             timevar = "rule", direction = "wide")
for (i in seq_len(nrow(w))) {
  cat(sprintf("%-12s %-9s", w$record[i], w$invader[i]))
  for (rn in c("a 1e-3", "a 1e-4", "b 0.3", "b 0.1", "b 0.03", "union 0.1", "union 0.03"))
    cat(sprintf(" | %s %.3f %4.1f%%", rn, w[i, paste0("eps.", rn)], 100 * w[i, paste0("saved.", rn)]))
  cat("\n")
}
