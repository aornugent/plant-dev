# score.R: each held-out case's reference (u215 -> u429, with its own move), E6 as built
# (committed c, check f) against it with C1-C5, 200 stress draws per noise model, cost, and
# the committed run's distance from eps. The bank's E6 pair is put through the same stress
# code as the comparison. Usage: Rscript score.R
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/heldout/cases.R")
LAD <- readRDS("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies/lad.rds")
Q <- LAD$Q; EPS <- LAD$EPS[Q]; M <- LAD$M_unit[Q]; NQ <- length(Q); ND <- 200
rms <- function(x) sqrt(mean(x^2))
crit4 <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25), C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE, C5 = all(est <= 1)) }
# E6's rule on (possibly perturbed) values vc, vf; judged on the true errors ec, ef.
e6_rule <- function(ec, ef, vc, vf, s) { est <- (vc - vf) / (1 - s)
  if (all(abs(est) < 1)) list(coarse = TRUE, err = ec, sest = est) else list(coarse = FALSE, err = ef, sest = (vc - vf) * s / (1 - s)) }
stress <- function(ec, ef, s, seed) { out <- sapply(c("coord", "jit"), function(nz) { r <- t(vapply(seq_len(ND), function(d) {
    set.seed(seed * 1e5 + d * 7 + (nz == "jit"))
    if (nz == "coord") { ms <- rnorm(NQ, 0, 0.025); vc <- ec + ms + rnorm(NQ, 0, 0.04); vf <- ef + ms + rnorm(NQ, 0, 0.04) }
    else { vc <- ec + rnorm(NQ, 0, 0.020) + 0.09 * rnorm(1) * M; vf <- ef + rnorm(NQ, 0, 0.020) + 0.09 * rnorm(1) * M }
    z <- e6_rule(ec, ef, vc, vf, s); cr <- crit4(z$err, z$sest); c(cr, pass = all(cr), coarse = z$coarse, W = max(abs(z$err))) }, numeric(7)))
    colMeans(r) }); out }
qv <- function(x) { q <- quantities(x); if (!all(Q %in% names(q))) return(NULL); q[Q] }
rows <- list(); keep <- list()
for (cs in names(HO)) {
  a <- HO_RUN(sprintf("ref_%s_u215", cs)); b <- HO_RUN(sprintf("ref_%s_u429", cs)); xc <- HO_RUN(sprintf("e6_c_%s", cs)); xf <- HO_RUN(sprintf("e6_f_%s", cs))
  have <- c(ref = !is.null(a) && !is.null(b) && !is.null(a$finished) && !is.null(b$finished), c = !is.null(xc$finished), f = !is.null(xf$finished))
  cat(sprintf("%-14s ref %s c %s f %s\n", cs, have["ref"], have["c"], have["f"])); if (!all(have)) next
  qa <- qv(a); qb <- qv(b); qc <- qv(xc); qf <- qv(xf); if (any(vapply(list(qa, qb, qc, qf), is.null, TRUE))) { cat("  missing quantities (refusal?)\n"); next }
  fin <- all(is.finite(c(qa, qb, qc, qf)))
  ref <- extrap(qa, qb); own <- (qb - qa) / 3 / EPS
  ec <- (qc - ref) / EPS; ef <- (qf - ref) / EPS; d <- ec - ef
  p <- pilot_of(cs); s <- alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times)
  z <- e6_rule(ec, ef, ec, ef, s); cr <- crit4(z$err, z$sest); estc <- d / (1 - s)
  big <- pmax(abs(z$err), abs(z$sest)) > 1 / 3; ok3 <- abs(z$sest[big]) >= abs(z$err[big]) / 2 & abs(z$sest[big]) <= 2 * abs(z$err[big]) & sign(z$sest[big]) == sign(z$err[big])
  Tc <- run_cost(xc$stand$rows, TRUE); Tf <- run_cost(xf$stand$rows, TRUE)
  st <- stress(ec, ef, s, match(cs, names(HO)))
  keep[[cs]] <- list(ec = ec, ef = ef, own = own, s = s, ref = ref, estc = estc, err = z$err, sest = z$sest)
  rows[[cs]] <- data.frame(case = cs, lnJ = ref[["lnJ"]], nc = length(xc$node_times), nf = length(xf$node_times), s = s,
    own_max = max(abs(own)), own_q = Q[which.max(abs(own))], own_rms = rms(own), finite = fin,
    Wc = max(abs(ec)), Wc_q = Q[which.max(abs(ec))], rms_c = rms(ec), M_c = sum(ec * M), Wf = max(abs(ef)), rms_f = rms(ef),
    commit = if (z$coarse) "c" else "f", W = max(abs(z$err)), pass = all(cr), fails = paste(names(cr)[!cr], collapse = ""), C3n = sprintf("%d/%d", sum(ok3), sum(big)),
    read = median((estc / ec)[abs(ec) > 0.2]), corr = cor(estc, ec), est_max = max(abs(z$sest)),
    s_star = sqrt(1 / max(abs(ec))), T = Tc + Tf + 2 * (if (z$coarse) Tc else Tf), Tc = Tc, Tf = Tf,
    cpu = xc$stand$cpu + xc$sweep_cpu + xf$stand$cpu + xf$sweep_cpu, ref_cpu = a$stand$cpu + a$sweep_cpu + b$stand$cpu + b$sweep_cpu,
    st_coord = st["pass", "coord"], st_jit = st["pass", "jit"], st_coord_C3 = st["C3", "coord"], st_jit_C3 = st["C3", "jit"],
    st_coord_C1 = st["C1", "coord"], st_coord_coarse = st["coarse", "coord"]) }
if (!length(rows)) quit()
TB <- do.call(rbind, rows); rownames(TB) <- NULL
options(width = 250); print(TB, digits = 3)
# The bank's E6 pairs through the same stress code.
BK <- do.call(rbind, lapply(names(LAD$L), function(cs) { l <- LAD$L[[cs]]; ec <- (l$runs$c$q - l$ref) / EPS; ef <- (l$runs$f$q - l$ref) / EPS
  s <- l$runs$f$proxy / l$runs$c$proxy; z <- e6_rule(ec, ef, ec, ef, s); st <- stress(ec, ef, s, 100 + match(cs, names(LAD$L)))
  data.frame(case = cs, Wc = max(abs(ec)), commit = if (z$coarse) "c" else "f", pass = all(crit4(z$err, z$sest)), read = median((((ec - ef) / (1 - s)) / ec)[abs(ec) > 0.2]),
    T = run_cost(l$runs$c$rows) + run_cost(l$runs$f$rows) + 2 * run_cost(if (z$coarse) l$runs$c$rows else l$runs$f$rows), st_coord = st["pass", "coord"], st_jit = st["pass", "jit"]) }))
cat("\nbank (same code):\n"); print(BK, digits = 3)
summ <- function(X, lab) cat(sprintf("%s: n %d | real pass %d | median Wc %.2f [%.2f-%.2f] | Wc<=0.39 %d | Wc>1 %d | median read %.2f | stress pass coord %.3f jit %.3f | T sum %.0f median %.0f\n",
  lab, nrow(X), sum(X$pass), median(X$Wc), min(X$Wc), max(X$Wc), sum(X$Wc <= 0.39), sum(X$Wc > 1), median(X$read), mean(X$st_coord), mean(X$st_jit), sum(X$T), median(X$T)))
cat("\n"); summ(TB, "held-out"); summ(BK, "bank    ")
pooled <- unlist(lapply(keep, function(k) (k$estc / k$ec)[abs(k$ec) > 0.2])); cat(sprintf("pooled read over |e_c| > 0.2: median %.2f (n %d)\n", median(pooled), length(pooled)))
# Per case: the quantities over eps/3 (committed error, check error, estimate, the
# reference's own move), C3 misses marked.
for (cs in names(keep)) { k <- keep[[cs]]; big <- pmax(abs(k$err), abs(k$sest)) > 1 / 3
  ok <- abs(k$sest) >= abs(k$err) / 2 & abs(k$sest) <= 2 * abs(k$err) & sign(k$sest) == sign(k$err)
  cat(sprintf("\n%s (s %.3f): %s\n", cs, k$s, paste(sprintf("%s%s ec %+.2f ef %+.2f est %+.2f own %+.2f", ifelse(ok[big], "", "*"), Q[big], k$ec[big], k$ef[big], k$sest[big], k$own[big]), collapse = "; "))) }
write.csv(TB, file.path(HO_OUT, "score_tab.csv"), row.names = FALSE)
saveRDS(list(tab = TB, bank = BK, keep = keep, Q = Q), file.path(HO_OUT, "score.rds"))
