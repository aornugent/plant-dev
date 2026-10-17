# h5_check.R: H5's ladders as they land: errors per rung, order, the two pairs' reads (spacing
# ratio form, as the loop uses), C1-C5, cost against E6's committed run.
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
D <- readRDS(file.path(PO, "lad_h5.rds")); L <- D$L; Q <- D$Q; EPS <- D$EPS; M <- D$M_unit[Q]
rms <- function(x) sqrt(mean(x^2)); SEC <- 113e-6; G1 <- function(r) r * SEC * 4.27
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25), C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE, C5 = all(est <= 1)) }
for (cs in names(L)) { l <- L[[cs]]; e <- lapply(l$runs, function(r) (r$q - l$ref) / EPS); e6 <- (l$E6c$q - l$ref) / EPS
  cat(sprintf("\n== %s (H5 rule N)\n", cs)); for (k in c("x", "c", "f")) cat(sprintf("  %s: nodes %d rows %.0f (x E6 c %.2f) | W %.2f (%s) rms %.3f along M %+.2f ln J %+.2f\n", k, length(l$runs[[k]]$S), l$runs[[k]]$rows, l$runs[[k]]$rows / l$E6c$rows,
    max(abs(e[[k]])), Q[which.max(abs(e[[k]]))], rms(e[[k]]), sum(e[[k]] * M), e[[k]][["lnJ"]]))
  cat(sprintf("  E6 committed: W %.2f rms %.3f\n", max(abs(e6)), rms(e6)))
  d1 <- e$x - e$c; d2 <- e$c - e$f; q <- sqrt(sum(d1^2) / sum(d2^2)); law <- (1.6^2 - 1) / (1 - 1.6^-2)
  cat(sprintf("  moves: |d1|/|d2| %.2f (law %.2f, p = %.2f), cos(d1, d2) %.2f; along M d1 %+.2f d2 %+.2f\n", q, law, 2 * log(q * (1 - 1.6^-2) / (1.6^2 - 1) * 2.56) / log(1.6) / 2 + 0, sum(d1 * d2) / sqrt(sum(d1^2) * sum(d2^2)), sum(d1 * M), sum(d2 * M)))
  for (pp in list(c("x", "c"), c("c", "f"), c("x", "f"))) { ra <- l$runs[[pp[1]]]$r; rb <- l$runs[[pp[2]]]$r; est <- (e[[pp[1]]] - e[[pp[2]]]) / ((ra / rb)^2 - 1); err <- e[[pp[2]]]
    cr <- crit(err, est); rd <- (est / err)[abs(err) > 0.2]
    cat(sprintf("  pair %s-%s, last run's estimate: read median %.2f [%.2f, %.2f] (n %d), corr %.2f, C1-C5 %s\n", pp[1], pp[2], median(rd), min(rd), max(rd), length(rd), cor(est, err), paste(names(cr), ifelse(cr, "ok", "FAIL"), collapse = " "))) } }
