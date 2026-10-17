# region.R [CASE ...]: the error of `off` and `all` at L by region, and the ladders.
# Regions are L's pairs: F founders, K (gap interval with the closing spell's last
# interval), P (gap interval with the opening spell's first interval), I interior, Z late
# (the residual). Per region R:
#   off:  e_off(R) = -4/3 (q(L_R, off) - q(L, off)), L_R = L with R's intervals halved
#         (order 2 assumed); Z = e_off - sum.
#   rule: d(R) = q(L, rule on R's pairs only) - q(L, off); e_all(R) = e_off(R) + d(R).
#   order under all in R: the move q(L_R, all) - q(L, all) against e_all(R):
#         shrink s = -<move, e>/|e|^2, order -log2(1 - s).
# Ladders (C2 / L / H2 nested): moves and order per rule, pooled and per quantity.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R"))
SU <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
SC <- readRDS(file.path(SU, "score.rds"))
A <- commandArgs(TRUE); SUF <- if (length(A) && A[1] %in% c("all", "allq")) A[1] else "all"; if (length(A) && A[1] %in% c("all", "allq")) A <- A[-1]
CS <- if (length(A)) A else names(SC)
q <- if (SUF == "allq") "q" else ""  # suffix of the rule's runs: windows L<R>win<q>, founders Lfounders<q>, halved L<R>all<q>
rd <- function(n, cs) { f <- file.path(SU, "runs", sprintf("%s_%s.rds", n, cs)); if (!file.exists(f)) return(NULL); x <- readRDS(f); if (is.null(x$stand$elasticity)) NULL else x }
qv <- function(x) quantities(x)[Q] / EPS
r2 <- function(x) sqrt(mean(x^2)); onM <- function(e) sum(e * M_unit[names(e)])
fm <- function(e) { o <- order(-abs(e))[1:2]; sprintf("rms %.3f worst %.2f M %+.2f lnJ %+.3f (%s)", r2(e), max(abs(e)), onM(e), e["lnJ"], paste(sprintf("%s %+.2f", names(e)[o], e[o]), collapse = ", ")) }
out <- list()
for (cs in CS) { ref <- SC[[cs]]$ref; L0 <- rd("Loff", cs); La <- rd(paste0("Lall", q), cs); if (is.null(L0) || is.null(La)) next
  cat(sprintf("\n==== %s (reference: %s)\n", cs, if (is.null(SC[[cs]]$rich)) "lib19-class" else "nested"))
  q0 <- qv(L0); qa <- qv(La); e0 <- q0 - ref; ea <- qa - ref
  cat(sprintf("off at L: %s\n%s at L: %s\n", fm(e0), SUF, fm(ea)))
  E0 <- list(); D <- list(); EA <- list(); MA <- list()
  for (R in c("F", "K", "P", "I")) {
    h0 <- rd(sprintf("L%soff", R), cs); if (!is.null(h0)) E0[[R]] <- -4 / 3 * (qv(h0) - q0)
    w <- rd(if (R == "F") paste0("Lfounders", q) else sprintf("L%swin%s", R, q), cs); if (!is.null(w)) D[[R]] <- qv(w) - q0
    ha <- rd(sprintf("L%sall%s", R, q), cs); if (!is.null(ha)) MA[[R]] <- qv(ha) - qa }
  if (length(E0) == 4) E0$Z <- e0 - Reduce(`+`, E0)
  if (length(D) == 4) D$Z <- (qa - q0) - Reduce(`+`, D)
  cat(" region | off error                                              | rule's change d(R)                                     | all error = off + d\n")
  for (R in c("F", "K", "P", "I", "Z")) { if (is.null(E0[[R]]) || is.null(D[[R]])) next; EA[[R]] <- E0[[R]] + D[[R]]
    cat(sprintf(" %s%s | %s | %s | %s\n", R, if (R == "Z") "*" else " ", fm(E0[[R]]), fm(D[[R]]), fm(EA[[R]]))) }
  for (R in names(MA)) { if (is.null(EA[[R]])) next; e <- EA[[R]]; m <- MA[[R]]; s <- -sum(m * e) / sum(e^2)
    m0 <- if (!is.null(E0[[R]])) -3 / 4 * E0[[R]] else NULL
    cat(sprintf("   %s halved under all: move rms %.3f (off: %.3f) | shrink of e_all(%s) %.2f -> order %.2f | cos(move, -e_all) %+.2f\n", R, r2(m), if (is.null(m0)) NA else r2(m0), R, s,
      if (s < 1 && s > 0) -log2(1 - s) else NA, -sum(m * e) / sqrt(sum(m^2) * sum(e^2)))) }
  # Ladder: C2 / L / H2.
  for (rule in c("off", "all", "allm", "allq")) { C <- rd(paste0("C2", rule), cs); Lr <- rd(paste0("L", rule), cs); H <- rd(paste0("H2", rule), cs); if (is.null(C) || is.null(Lr) || is.null(H)) next
    m1 <- qv(C) - qv(Lr); m2 <- qv(Lr) - qv(H); p <- log2(r2(m1) / r2(m2)); pq <- log2(abs(m1) / abs(m2)); big <- abs(m2) > 0.05
    cat(sprintf(" ladder %-4s: C2-L rms %.3f, L-H2 rms %.3f | pooled order %.2f | per quantity (|L-H2| > 0.05, n %d) median %.2f [%.2f, %.2f] | cos(m1, m2) %+.2f | lnJ moves %+.3f %+.3f\n",
      rule, r2(m1), r2(m2), p, sum(big), median(pq[big]), quantile(pq[big], 0.25), quantile(pq[big], 0.75), sum(m1 * m2) / sqrt(sum(m1^2) * sum(m2^2)), m1["lnJ"], m2["lnJ"])) }
  out[[cs]] <- list(E0 = E0, D = D, EA = EA, MA = MA) }
saveRDS(out, file.path(SU, sprintf("region_%s.rds", SUF)))
