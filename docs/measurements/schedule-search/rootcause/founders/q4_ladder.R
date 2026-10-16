# q4_ladder.R: the founders' window by trapezium (libS) and by Simpson (libF) on the
# committed schedule's founders' nodes replaced by f even intervals. Founders' error
# against q_inf = q48 + (q48 - q24)/3 of the trapezium ladder; the committed layer's
# own founders' error (fbis) beside it; cost in rows.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
rd <- function(n) { f <- file.path(FO, "runs", paste0(n, ".rds")); if (!file.exists(f)) return(NULL); readRDS(f) }
qv <- function(x) quantities(x)[Q] / EPS
rms <- function(x) sqrt(mean(x^2)); top <- function(x, n = 3) { o <- order(-abs(x))[1:n]; paste(sprintf("%s %+.3f", names(x)[o], x[o]), collapse = ", ") }
g <- rd("ladG12_dry"); t12 <- rd("ladT12_dry")
if (!is.null(g) && !is.null(t12)) cat(sprintf("S0 guard: libF unset J %.15g, libS J %.15g, rel %.1e\n\n", g$stand$J, t12$stand$J, g$stand$J / t12$stand$J - 1))
res <- list()
for (cs in c("dry", "episodic-lma")) {
  T <- lapply(c(6, 12, 24, 48), function(f) rd(sprintf("ladT%d_%s", f, cs))); names(T) <- c(6, 12, 24, 48)
  S <- lapply(c(6, 12, 24), function(f) rd(sprintf("ladS%d_%s", f, cs))); names(S) <- c(6, 12, 24)
  if (is.null(T[["24"]]) || is.null(T[["48"]])) { cat(cs, ": trapezium ladder incomplete\n"); next }
  qinf <- qv(T[["48"]]) + (qv(T[["48"]]) - qv(T[["24"]])) / 3
  c0 <- qv(readRDS(file.path(ADJ, sprintf("val_insk_c_%s.rds", cs)))); fb <- qv(rd(sprintf("fbis_%s", cs)))
  ref <- REF$L19[[cs]][Q] / EPS
  cat(sprintf("== %s (q_inf - reference: rms %.3f, the rest of the schedule's error)\n", cs, rms(qinf - ref)))
  cat(" rule      f | nodes rows       | founders' error rms  worst   ln J  | largest\n")
  line <- function(lab, f, x) { if (is.null(x)) return(invisible()); e <- qv(x) - qinf
    cat(sprintf(" %-9s %2s | %3d %9.0f | %.4f %.4f %+.4f | %s\n", lab, f, length(x$node_times), x$stand$rows, rms(e), max(abs(e)), e["lnJ"], top(e))); e }
  eT <- lapply(names(T), function(f) line("trapezium", f, T[[f]])); names(eT) <- names(T)
  eS <- lapply(names(S), function(f) line("Simpson", f, S[[f]])); names(eS) <- names(S)
  ec <- c0 - qinf; ef <- -4 / 3 * (fb - c0)
  cat(sprintf(" committed  (17-19 founders' intervals): rows %.0f | its founders' error by bisection (fbis) rms %.4f worst %.4f; c - q_inf rms %.4f\n",
    readRDS(file.path(ADJ, sprintf("val_insk_c_%s.rds", cs)))$stand$rows, rms(ef), max(abs(ef)), rms(ec)))
  r <- function(a, b) if (!is.null(a) && !is.null(b)) rms(a) / rms(b) else NA
  cat(sprintf(" trapezium shrink per halving: 6/12 %.2f, 12/24 %.2f | Simpson: 6/12 %.2f, 12/24 %.2f | Simpson/trapezium at 6, 12, 24: %.2f %.2f %.2f\n",
    r(eT[["6"]], eT[["12"]]), r(eT[["12"]], eT[["24"]]), r(eS[["6"]], eS[["12"]]), r(eS[["12"]], eS[["24"]]), r(eS[["6"]], eT[["6"]]), r(eS[["12"]], eT[["12"]]), r(eS[["24"]], eT[["24"]])))
  if (!is.null(eS[["12"]]) && !is.null(eT[["12"]])) cat(sprintf(" cos(Simpson f12 error, trapezium f12 error) %+.2f\n", sum(eS[["12"]] * eT[["12"]]) / sqrt(sum(eS[["12"]]^2) * sum(eT[["12"]]^2))))
  res[[cs]] <- list(eT = eT, eS = eS, ef = ef) }
saveRDS(res, file.path(FO, "q4_ladder.rds"))
# Reference-free reads: the Simpson ladder's own moves (no q_inf), and the jitter scale.
for (cs in names(res)) { S <- res[[cs]]$eS; T <- res[[cs]]$eT
  m1 <- S[["6"]] - S[["12"]]; m2 <- S[["12"]] - S[["24"]]
  cat(sprintf("%s Simpson moves (q_inf cancels): 6->12 rms %.4f, 12->24 rms %.4f, ratio %.1f, cos %+.2f | trapezium moves 24->48 rms %.4f | Simpson 12 - trapezium 48 rms %.4f\n",
    cs, rms(m1), rms(m2), rms(m1) / rms(m2), sum(m1 * m2) / sqrt(sum(m1^2) * sum(m2^2)), rms(T[["24"]] - T[["48"]]), rms(S[["12"]] - T[["48"]]))) }
