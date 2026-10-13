# Real runs (val_<TAG>): does the check at theta0 read the committed error at a moved
# trait theta1? Pairs: (episodic, episodic-lma), (dry, dry-p50), (long-wet, wet-adG2).
# For each, theta1's committed error against theta1's own estimate and theta0's estimate.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R")); EXCLUDED <<- c(EXCLUDED, "rooting_depth_max")
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/base.R", A <- new.env())
tag <- Sys.getenv("TAG", "a09"); R <- AR
pilot_of <- function(case) { cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
  list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")])) }
refq <- function(case) if (!is.null(CASES[[case]])) reference(case) else {
  x <- quantities(readRDS(file.path(R, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(R, sprintf("ref_%s_u429.rds", case))))
  k <- intersect(names(x), names(y)); extrap(x[k], y[k]) }
one <- function(case) { xc <- readRDS(file.path(R, sprintf("val_%s_c_%s.rds", tag, case))); xf <- readRDS(file.path(R, sprintf("val_%s_f_%s.rds", tag, case)))
  ref <- refq(case); qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k)
  p <- pilot_of(case); s <- A$proxy_err(p, xf$node_times) / A$proxy_err(p, xc$node_times)
  list(S = xc$node_times, ec = (qc[k] - ref[k]) / e, est = (qc[k] - qf[k]) / e / (1 - s), s = s, ef = (qf[k] - ref[k]) / e) }
grade <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  sprintf("C1 %d C2 %d C3 %d (%d/%d) C5 %d, read median %.2f", all(abs(err) <= 1), all(est[abs(err) > 0.5] > 0.25), sum(!ok3) <= max(1, floor(0.2 * sum(big))),
    sum(ok3), sum(big), all(est <= 1), median((sest / err)[abs(err) > 0.2])) }
PAIRS <- Sys.getenv("PAIRS", "episodic:episodic-lma,dry:dry-p50,long-wet:wet-adG2")
for (pr in strsplit(strsplit(PAIRS, ",")[[1]], ":")) {
  a <- one(pr[1]); b <- one(pr[2]); k <- intersect(names(a$ec), names(b$ec))
  sh <- mean(round(b$S, 6) %in% round(a$S, 6))
  cat(sprintf("%s -> %s: nodes %d / %d, shared %.2f; s %.2f / %.2f; cor(err0, err1) %.2f, rms(err1 - err0) %.2f\n", pr[1], pr[2], length(a$S), length(b$S), sh, a$s, b$s,
    cor(a$ec[k], b$ec[k]), sqrt(mean((b$ec[k] - a$ec[k])^2))))
  cat("   own estimate      :", grade(b$ec[k], b$est[k]), "\n")
  cat("   theta0's estimate :", grade(b$ec[k], a$est[k]), "\n")
  o <- order(-abs(b$ec[k]))[1:6]; print(round(rbind(err1 = b$ec[k][o], est1 = b$est[k][o], err0 = a$ec[k][o], est0 = a$est[k][o]), 2)) }
# ln J's own move (the cheap forward-only check at theta1) against theta0's.
if (nzchar(Sys.getenv("LNJ"))) for (pr in strsplit(strsplit(PAIRS, ",")[[1]], ":")) { a <- one(pr[1]); b <- one(pr[2])
  cat(sprintf("  lnJ %s -> %s: err0 %+.2f est0 %+.2f | err1 %+.2f est1 %+.2f | est1/est0 %.2f\n", pr[1], pr[2], a$ec["lnJ"], a$est["lnJ"], b$ec["lnJ"], b$est["lnJ"], b$est["lnJ"] / a$est["lnJ"])) }
# Committing theta1's finer schedule on theta0's estimate (est0 * s0), and the largest miss.
if (nzchar(Sys.getenv("FINE"))) for (pr in strsplit(strsplit(PAIRS, ",")[[1]], ":")) { a <- one(pr[1]); b <- one(pr[2]); k <- intersect(names(a$ec), names(b$ec))
  cat(sprintf("  %s -> %s: coarse max|err1 - est0| %.2f (own %.2f) | fine: worst %.2f, %s\n", pr[1], pr[2], max(abs(b$ec[k] - a$est[k])), max(abs(b$ec[k] - b$est[k])),
    max(abs(b$ef[k])), grade(b$ef[k], a$est[k] * a$s))) }
