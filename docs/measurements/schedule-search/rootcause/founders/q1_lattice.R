# q1_lattice.R: the founders' axis of the lattice (f even nodes over [0, b1), l = 70; lib,
# 3e-5). Order, size and direction of the founders' error per case.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
v <- function(cs, f, l = 70) { nm <- sprintf("lat_%s_f%d_l%s", cs, f, l); if (!nm %in% TAB$name) return(NULL); qn(nm)[Q] / EPS }
TR <- c("dry", "episodic", "episodic-lma", "long-wet", "long-drought"); HO <- c("dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")
ordp <- function(d1, d2) -log2(sum(d1 * d2) / sum(d1^2))
rms <- function(x) sqrt(mean(x^2))
top <- function(x, n = 5) { o <- order(-abs(x))[1:n]; paste(sprintf("%s %+.2f", names(x)[o], x[o]), collapse = ", ") }
res <- list()
for (cs in c(TR, HO)) {
  V <- lapply(c(8, 16, 32, 64), function(f) v(cs, f)); names(V) <- c(8, 16, 32, 64)
  vinf <- V[["64"]] + (V[["64"]] - V[["32"]]) / 3
  ref <- REF$L19[[cs]][Q] / EPS
  out <- list(case = cs, vinf = vinf)
  if (!is.null(V[["8"]])) {
    d1 <- V[["16"]] - V[["8"]]; d2 <- V[["32"]] - V[["16"]]; d3 <- V[["64"]] - V[["32"]]
    big <- abs(d2) > 0.1
    pq <- -log2(d3[big] / d2[big])
    cat(sprintf("%-13s moves rms 8>16 %.3f 16>32 %.3f 32>64 %.3f | pooled order (8,16,32) %.2f (16,32,64) %.2f | cos(d1,d2) %.2f cos(d2,d3) %.2f | per-q order 16-32-64 median %.2f [n %d]\n",
      cs, rms(d1), rms(d2), rms(d3), ordp(d1, d2), ordp(d2, d3), sum(d1 * d2) / sqrt(sum(d1^2) * sum(d2^2)), sum(d2 * d3) / sqrt(sum(d2^2) * sum(d3^2)), median(pq), sum(big)))
    for (f in c("8", "16", "32")) { e <- V[[f]] - vinf
      cat(sprintf("   founders' error f=%-2s rms %.3f max %.3f lnJ %+.3f M %+.2f | %s\n", f, rms(e), max(abs(e)), e["lnJ"], sum(e * M_unit), top(e))) }
    out$eF16 <- V[["16"]] - vinf; out$eF8 <- V[["8"]] - vinf; out$eF32 <- V[["32"]] - vinf
    e16 <- V[["16"]] - ref
    cat(sprintf("   lat (16,70) total err rms %.3f; founders' share of its squared error (projection) %.0f%%, |eF|^2/|e|^2 %.0f%%\n", rms(e16), 100 * sum(out$eF16 * e16) / sum(e16^2), 100 * sum(out$eF16^2) / sum(e16^2)))
  } else {
    d3 <- V[["64"]] - V[["32"]]; e <- V[["32"]] - vinf
    cat(sprintf("%-13s move 32>64 rms %.3f | founders' error f=32 (4/3 move) rms %.3f lnJ %+.3f | %s\n", cs, rms(d3), rms(e), e["lnJ"], top(e)))
    out$eF32 <- e }
  res[[cs]] <- out }
cosm <- function(key, cases) { m <- sapply(cases, function(cs) res[[cs]][[key]]); C <- crossprod(m) / sqrt(outer(colSums(m^2), colSums(m^2))); round(C, 2) }
cat("\ncos of founders' error at f = 16 (training):\n"); print(cosm("eF16", TR))
cat("\ncos of founders' error at f = 32 (all ten):\n"); print(cosm("eF32", c(TR, HO)))
# per-case size scaling: rms at f=16 against f=32 (order check on the error itself)
cat("\nsize ratio eF8/eF16 and eF16/eF32 (rms):\n")
for (cs in TR) cat(sprintf("  %-13s %.2f %.2f\n", cs, rms(res[[cs]]$eF8) / rms(res[[cs]]$eF16), rms(res[[cs]]$eF16) / rms(res[[cs]]$eF32)))
saveRDS(res, file.path(FO, "q1_lattice.rds"))
