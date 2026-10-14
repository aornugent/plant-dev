# cmp.R CASE BASE.rds NEW.rds: cost and every quantity's move in eps, NEW against BASE,
# and each against the case's reference (harness/schedule anyscore.R).
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
a <- commandArgs(TRUE); case <- a[1]; b <- readRDS(a[2]); n <- readRDS(a[3])
cost <- function(x) c(steps = length(x$stand$times) - 1, rows = x$stand$rows, fwd = x$stand$cpu,
                      sweep = if (is.null(x$sweep_cpu)) NA else x$sweep_cpu)
cb <- cost(b); cn <- cost(n)
print(rbind(base = cb, new = cn, ratio = cn / cb), digits = 4)
qb <- quantities(b); qn <- quantities(n); k <- intersect(names(qb), names(qn)); k <- k[!k %in% EXCLUDED]
mv <- (qn[k] - qb[k]) / eps_vec(k)
ref <- tryCatch(reference(case), error = function(e) NULL)
cat(sprintf("J base %.10g new %.10g; moves in eps: max |.| %.3f (%s), rms %.3f, ln J %+.4f; over 1/3: %d of %d\n",
  b$stand$J, n$stand$J, max(abs(mv)), names(mv)[which.max(abs(mv))], sqrt(mean(mv^2)), mv[["lnJ"]], sum(abs(mv) > 1/3), length(mv)))
o <- order(-abs(mv)); print(round(head(mv[o], 10), 3))
if (!is.null(ref)) {
  kk <- intersect(k, names(ref)); eb <- (qb[kk] - ref[kk]) / eps_vec(kk); en <- (qn[kk] - ref[kk]) / eps_vec(kk)
  cat(sprintf("against the reference: base max %.3f rms %.3f | new max %.3f rms %.3f (eps)\n",
    max(abs(eb)), sqrt(mean(eb^2)), max(abs(en)), sqrt(mean(en^2))))
}
cat(sprintf("refusal: base %s new %s\n", format(b$refusal), format(n$refusal)))
